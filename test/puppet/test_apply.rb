require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'

require 'test/unit'

class TestPuppetRoles < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'ppm', :vagrantfile => '../piab/Vagrantfile')
    @ppm.rebuild() unless @ppm.status.eql?('running') # destroy / rebuild

    @app = Rouster.new(:name => 'app', :vagrantfile => '../piab/Vagrantfile')

    assert_nothing_raised do
      @ppm.run_puppet('masterless', {
        :expected_exitcode => [0,2],
        :hiera_config      => 'hiera.yaml',
        :manifest_file     => '/etc/puppet/manifests/manifest.pp',
        :module_dir        => '/etc/puppet/modules/'
      })
    end

    assert_match(/Finished catalog run in/, @ppm.get_output())

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
            :group  => 'root',
        }
    }

    # manually specified testing
    @expected_files.each_pair do |f,e|
      assert_equal(true, @ppm.validate_file(f,e))
    end

    @expected_groups.each_pair do |g,e|
      assert_equal(true, @ppm.validate_group(g,e))
    end

    @expected_packages.each_pair do |p,e|
      assert_equal(true, @ppm.validate_package(p, e))
    end

    @expected_services.each_pair do |s,e|
      assert_equal(true, @ppm.validate_service(s,e))
    end

    @expected_users.each_pair do |u,e|
      assert_equal(true, @ppm.validate_user(u,e))
    end

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
      @app.up()
      @app.run_puppet('masterless', {
        :expected_exitcode => [0,2],
        :hiera_config      => 'hiera.yaml',
        :manifest_file     => '/etc/puppet/manifests/manifest.pp',
        :module_dir        => '/etc/puppet/modules/'
      })

    end

    assert_match(/Finished catalog run in/, @app.get_output())

    # manually specified testing
    app_expected_files.each_pair do |f,e|
      assert_equal(true, @app.validate_file(f,e))
    end

    app_expected_groups.each_pair do |g,e|
      assert_equal(true, @app.validate_group(g,e))
    end

    app_expected_packages.each_pair do |p,e|
      assert_equal(true, @app.validate_package(p, e))
    end

    app_expected_services.each_pair do |s,e|
      assert_equal(true, @app.validate_service(s,e))
    end

    app_expected_users.each_pair do |u,e|
      assert_equal(true, @app.validate_user(u,e))
    end

  end

  def teardown
    # noop
  end

end
