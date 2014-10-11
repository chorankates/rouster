require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetServices < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'default', :cache_timeout => 10)
    end

    @app.up()

    @allowed_states = %w(exists installed operational running stopped unsure)
  end

  def test_happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_services()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:services])

    res.each_key do |k|
      assert_not_nil(res[k])
      assert(@allowed_states.member?(res[k]))
    end

    # this isn't the best validation, but does prove a point - no nil keys/values
    assert_nothing_raised do
      res.keys.sort
      res.values.sort
    end

  end

  def test_happy_path_caching

    assert_nil(@app.deltas[:services])

    assert_nothing_raised do
      @app.get_services(true)
    end

    assert_equal(Hash, @app.deltas[:services].class)

  end

  def test_happy_path_cache_invalidation
    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_services(true)
    end

    first_cache_time = @app.cache[:services]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_services(true)
    end

    second_cache_time = @app.cache[:services]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)
    assert(second_cache_time > first_cache_time)

  end

  def teardown
    @app = nil
  end

end
