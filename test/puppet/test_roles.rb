require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'ppm')
    @ppm.rebuild() # destroy / rebuild

    assert_nothing_raised do
		  @ppm.run_puppet([0,2])
    end

    assert_match(/Finished catalog run in/, @ppm.get_output())

    # define base here
    @expected_packages = {
      'puppet' => { :ensure => true },
      'facter' => { :ensure => true }
    }

    @expected_files = {
      '/etc/passwd' => {
        :ensure   => 'file',
        :contains => [ 'puppet', 'root']
      }
    }

    @expected_groups   = Hash.new()
    @expected_services = Hash.new()
    @expected_users    = Hash.new()
  end

  def test_app
    app = Rouster.new(:name => 'app')

    app_expected_packages = {
      'perl-DBI' => { :ensure => 'present' },
      'rsync'    => { :ensure => 'present' }
    }.merge(@expected_packages)

    app_expected_files = {
      '/etc/hosts' => {
          :ensure   => 'present',
          :contains => [ 'localhost', 'app' ]
      },
    }.merge(@expected_files)

    app_expected_groups   = {}.merge(@expected_groups)
    app_expected_services = {}.merge(@expected_services)
    app_expected_users    = {}.merge(@expected_users)

    assert_nothing_raised do
      app.up()
      app.run_puppet(2)
    end

    assert_match(/Finished catalog run in/, app.get_output())

    # manually specified testing
    app_expected_files.each_pair do |f,e|
      assert_equal(true, app.validate_file(f,e))
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
    db = Rouster.new(:name => 'db')

    # TODO implement parse_catalog here
    catalog = db.get_catalog()
    expectations = db.parse_catalog(catalog)

    assert_nothing_raised do
      db.up()
      db.run_puppet(2)
    end

    assert_match(/Finished catalog run in/, db.get_output())

    expectations.each_pair do |k,v|
      res = nil
      case v[:type]
        when :dir

        when :file
        when :group
        when :package
        when :user
        when :service
      end

      assert_equal(true, res, sprintf('failed[%s]: %s',v, res))
    end

    db.destroy()
  end

  def teardown
    # noop
  end

end
