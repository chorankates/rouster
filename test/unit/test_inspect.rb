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
    # want to do this with 'assert_method_called' or something similar
  end

  def teardown
    # noop
  end

end