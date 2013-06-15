require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_groups()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:groups])

    res.each_key do |k|
      assert_not_nil(res[k][:users])
      assert_equal(res[k][:users].class, Array)
      assert_not_nil(res[k][:gid])
    end

  end

  # TODO add some non-caching tests

  def teardown
    @app = nil
  end

end
