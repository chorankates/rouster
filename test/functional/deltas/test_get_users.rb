require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetUsers < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_users()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:users])

    res.each_key do |k|
      assert_not_nil(res[k][:shell])
      assert_not_nil(res[k][:uid])
      assert_match(/^\d+$/, res[k][:uid])
      assert_not_nil(res[k][:gid])
      assert_match(/^\d+$/, res[k][:gid])
      assert_not_nil(res[k][:home])
      assert_not_nil(res[k][:home_exists])
    end

  end

  # TODO add some caching tests

  def teardown
    @app = nil
  end

end
