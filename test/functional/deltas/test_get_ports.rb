require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetPorts < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nil(@app.deltas[:ports])

    assert_nothing_raised do
      res = @app.get_ports()
    end

    assert_equal(Hash, res.class)

    res.each_key do |proto|
      assert_not_nil(res[proto])

      res[proto].each_key do |port|
        assert_not_nil(res[proto][port])
      end

    end

    assert_nil(@app.deltas[:ports])

  end

  def test_happy_path_caching

    assert_nil(@app.deltas[:ports])

    assert_nothing_raised do
      @app.get_ports(true)
    end

    assert_equal(Hash, @app.deltas[:ports].class)

  end

  def teardown
    @app = nil
  end

end
