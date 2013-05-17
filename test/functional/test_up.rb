require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

  end

  def test_happy_path
    assert_nothing_raised do
      @app.up()
    end

    assert_equal(true, @app.is_available_via_ssh?)
  end

  def teardown
    # noop
  end

end
