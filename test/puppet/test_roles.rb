require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'

require 'test/unit'

class TestPuppetRoles < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'ppm', :vagrantfile => '../piab/Vagrantfile')
    @ppm.rebuild() # destroy / rebuild

    assert_nothing_raised do
		  @ppm.run_puppet([0,2])
    end

    #assert_match(/Finished catalog run in/, @ppm.get_output())

    # define base here
    @expected_packages = {
      'puppet' => { :ensure => true },
      'facter' => { :ensure => true }
    }

    @expected_files = {
      '/etc/passwd' => {
        :contains => [ 'vagrant', 'root'],
        :ensure   => 'file',
        :group    => 'root',
        :mode     => '0644',
        :owner    => 'root'
      },

      '/tmp/foo/' => {
        :ensure => 'directory',
        :group  => 'root',
        :owner  => 'root',
      }
    }

    @expected_groups   = {
        'root' => { :ensure => true }
    }

    @expected_services = Hash.new()
    @expected_users    = Hash.new()
  end

  def test_app
    app = Rouster.new(:name => 'app', :vagrantfile => '../piab/Vagrantfile')

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
      'bar' => {
        :ensure => 'present',
      }
    }.merge(@expected_groups)

    app_expected_services = {}.merge(@expected_services)

    app_expected_users    = {
      'foo' => {
        :ensure => 'present',
        :group  => 'bar',
      }
    }.merge(@expected_users)

    assert_nothing_raised do
      app.up()
      app.run_puppet([0, 2])
    end

    #assert_match(/Finished catalog run in/, app.get_output())

    # manually specified testing
    app_expected_files.each_pair do |f,e|
      #assert_equal(true, app.validate_file(f,e))
    end

    app_expected_groups.each_pair do |g,e|
       assert_equal(true, app.validate_group(g,e))
    end

    app_expected_packages.each_pair do |p,e|
      assert_equal(true, app.validate_package(p, e))
    end

    app_expected_services.each_pair do |s,e|
      assert_equal(true, app.validate_service(s,e))
    end

    app_expected_users.each_pair do |u,e|
      assert_equal(true, app.validate_user(u,e))
    end

    app.destroy()
  end


  def test_db
    db = Rouster.new(:name => 'db', :vagrantfile => '../piab/Vagrantfile')

    # TODO implement parse_catalog here
    catalog      = db.get_catalog()
    expectations = db.parse_catalog(catalog)

    assert_nothing_raised do
      db.up()
      db.run_puppet(2)
    end

    assert_match(/Finished catalog run in/, db.get_output())

    expectations.each_pair do |k,v|
      res = nil
      case v[:type]
        when :dir, :file
          res = db.validate_file(k, v)
        when :group
          res = db.validate_group(k, v)
        when :package
          res = db.validate_package(k, v)
        when :user
          res = db.validate_user(k, v)
        when :service
          res = db.validate_service(k, v)
      end

      assert_equal(true, res, sprintf('failed[%s]: %s',v, res))
    end

    db.destroy()
  end

  def teardown
    # noop
  end

end
