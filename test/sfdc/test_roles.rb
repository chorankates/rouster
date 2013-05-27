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
            :contains => [ 'sfdc', 'root']
        }
    }
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

    assert_raises_nothing do
      app.run_puppet(2)
    end

    assert_match(/Finished catalog run in/, app.get_output())

    app.destroy()
  end


  def test_db
    db = Rouster.new(:name => 'db')

    db_expected_packages = {
        'jdk' => { :ensure => 'present', }
    }.merge(@expected_packages)

    db_expected_files =  {
        '/root' => { :ensure => 'directory' }
    }.merge(@expected_files)


    assert_raises_nothing do
      db.run_puppet(2)
    end

    assert_match(/Finished catalog run in/, db.get_output())

    db.destroy()
  end

  def teardown
    # noop
  end

end
