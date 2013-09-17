require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'

require 'test/unit'

class TestPuppetApply < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app', :verbose => 1)

    ## TODO teach put() how to use -R (directories)
    required_files = {
      'test/puppet/manifests/default.pp'             => 'manifests/default.pp',
      'test/puppet/manifests/hiera.yaml'             => 'manifests/hiera.yaml',
      'test/puppet/manifests/manifest.pp'            => 'manifests/manifest.pp',
      'test/puppet/manifests/hieradata/common.json'  => 'manifests/hieradata/common.json',
      'test/puppet/manifests/hieradata/vagrant.json' => 'manifests/hieradata/vagrant.json',
      'test/puppet/modules/role/manifests/ui.pp'     => 'modules/role/manifests/ui.pp',
    }

    ## TODO figure out a better pattern here -- scp tunnel is under 'vagrant' context, but dirs created with 'root'
    @app.sudo = false
    @app.run('mkdir -p manifests/hieradata')
    @app.run('mkdir -p modules/role/manifests')
    @app.sudo = true

    required_files.each_pair do |source,dest|
      @app.put(source, dest)
    end

    assert_nothing_raised do
      @app.run_puppet('masterless', {
        :expected_exitcode => [0,2],
        :hiera_config      => 'manifests/hiera.yaml',
        :manifest_file     => 'manifests/manifest.pp',
        :module_dir        => 'modules/'
      })
    end

    assert_match(/this is a test/, @app.get_output())
    assert_match(/Finished catalog run in/, @app.get_output())

    # define base here
    @expected_packages = {
      'puppet' => { :ensure => true },
      'facter' => { :ensure => 'present' }
    }

    @expected_files = {
      '/etc/passwd' => {
        :contains => [ 'vagrant', 'root'],
        :ensure   => 'file',
        :group    => 'root',
        :mode     => '0644',
        :owner    => 'root'
      },

      '/tmp' => {
        :ensure => 'directory',
        :group  => 'root',
        :owner  => 'root',
      }
    }

    @expected_groups   = {
      'root' => { :ensure => 'true' }
    }

    @expected_services = Hash.new()
    @expected_users    = {
      'root' => {
        :ensure => 'present',
        #:group  => 'root',
      }
    }

  end

  def test_app
    app_expected_packages = {
      'rsync'    => { :ensure => 'present' }
    }.merge(@expected_packages)

    app_expected_files = {
      '/etc/hosts' => {
        :contains => [ 'localhost', 'app' ],
        :ensure   => 'present',
        :group    => 'root',
        :owner    => 'root',
      },
    }.merge(@expected_files)

    app_expected_groups   = {
      'vagrant' => {
        :ensure => 'present',
      }
    }.merge(@expected_groups)

    app_expected_services = {}.merge(@expected_services)

    app_expected_users    = {
      'vagrant' => {
        :ensure => 'present',
      },
    }.merge(@expected_users)

    assert_nothing_raised do
      @app.run_puppet('masterless', {
        :expected_exitcode => [0,2],
        :hiera_config      => 'manifests/hiera.yaml',
        :manifest_dir      => 'manifests/',
        :module_dir        => 'modules/'
      })

    end

    assert_match(/Finished catalog run in/, @app.get_output()) # this only examines the last manifest run

    # manually specified testing
    app_expected_files.each_pair do |f,e|
      assert_equal(true, @app.validate_file(f,e), "file[#{f}] expectation[#{e}]")
    end

    app_expected_groups.each_pair do |g,e|
      assert_equal(true, @app.validate_group(g,e), "group[#{g}] expectation[#{e}]")
    end

    app_expected_packages.each_pair do |p,e|
      assert_equal(true, @app.validate_package(p, e), "package[#{p}] expectation[#{e}]")
    end

    app_expected_services.each_pair do |s,e|
      assert_equal(true, @app.validate_service(s,e), "service[#{s}] expectation[#{e}]")
    end

    app_expected_users.each_pair do |u,e|
      assert_equal(true, @app.validate_user(u,e), "user[#{u}] expectation[#{e}]")
    end

  end

  def teardown
    # noop
  end

end
