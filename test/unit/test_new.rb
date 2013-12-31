require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

# TODO add a bad perms test -- though it should be fixed automagically

class TestNew < Test::Unit::TestCase

  def setup
    @app = nil
    # TODO make this work, don't want to have to instance_variable_get everything..
    #Rouster.send(:public, *Rouster.instance_variables)
  end

  # TODO this is an awful pattern, do better

  def test_1_good_basic_instantiation

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :unittest => true)
    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.is_passthrough?())
    assert_equal(true, @app.uses_sudo?())
  end

  def test_2_good_instantiation

    assert_nothing_raised do
      @app = Rouster.new(
        :cache_timeout => 10,
        :name          => 'ppm',
        :retries       => 3,
        :verbosity     => [3,2],
        :unittest      => true,
      )
    end

    assert_equal(10, @app.cache_timeout)
    assert_equal('ppm', @app.name)
    assert_equal(3, @app.retries)

    assert_equal(3, @app.instance_variable_get(:@verbosity_console))
    assert_equal(2, @app.instance_variable_get(:@verbosity_logfile))

  end

  def teardown
    # noop
  end

end
