require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')
  end

  def test_happy_path

    assert_nothing_raised do
      @app.generate_unique_mac
    end

  end

  def test_uniqueness
    a = @app.generate_unique_mac
    b = @app.generate_unique_mac

    assert_not_equal(a, b)

  end

  def teardown
    # noop
  end

end