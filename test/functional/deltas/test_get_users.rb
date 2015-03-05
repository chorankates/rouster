require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetUsers < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 10)
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

  def test_happy_path_caching

    assert_nil(@app.deltas[:users])

    assert_nothing_raised do
      @app.get_users(true)
    end

    assert_equal(Hash, @app.deltas[:users].class)

  end

  def test_happy_path_cache_invalidation
    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_users(true)
    end

    first_cache_time = @app.cache[:users]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_users(true)
    end

    second_cache_time = @app.cache[:users]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)
    assert(second_cache_time > first_cache_time)

  end

  def teardown
    @app = nil
  end

end
