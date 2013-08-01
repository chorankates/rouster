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

    assert_nothing_raised do
      res = @app.get_ports()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:ports])

    res.each_key do |proto|
      assert_not_nil(res[proto])

      proto.each_key do |port|
        assert_not_nil(res[proto][port])
      end

    end

  end

  # TODO add some non-caching tests

  def teardown
    @app = nil
  end

end
