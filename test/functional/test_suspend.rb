require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestSuspend < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'default')
    end

  end

  def test_happy_path
    @app.up()

    assert_equal(true, @app.is_available_via_ssh?)

    assert_nothing_raised do
      @app.suspend()
    end

    assert_equal(false, @app.is_available_via_ssh?)
  end

  def teardown
    # noop
  end

end
