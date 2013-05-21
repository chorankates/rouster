require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'ppm')
    @ppm.rebuild() # destroy / rebuild

    assert_nothing_raised do
      @ppm.run_puppet()
    end

    assert(@ppm.exitcode.eql?(0) or @ppm.exitcode.eql?(2))
    assert_match(/Finished catalog run in/, @ppm.get_output())

    # define base here
    @expected_packages = {

    }

    @expected_files = {

    }
  end

  def test_app
    app = Rouster.new(:name => 'app')

    app_expected_packages = {
        'perl-DBI' => { :ensure => 'present' },
        'rsync'    => { :ensure => 'present' },
    }

    app_expected_files = {
        '/etc/hosts' => {
            :ensure   => 'present',
            :contains => [ 'localhost', 'app' ],
        },

    }

    e = assert_raise Rouster::InternalError do
      @app.run_puppet()
    end

    assert(@app.exitcode.eql?(2))
    assert_match(/Finished catalog run in/, e, 'ensuring exception is expected')
    assert_match(/Finished catalog run in/, @app.get_output())


    app.destroy()
  end


  def teardown
    # noop
  end

end
