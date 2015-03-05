require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestFacter < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 10)
    end

    @app.up()
  end

  def test_happy_path

    facts = nil

    assert_nothing_raised do
      facts = @app.facter()
    end

    assert_equal(true, facts.class.eql?(Hash))
    assert_equal(facts, @app.facts)
  end

  def test_negative_caching

    facts = nil

    assert_nothing_raised do
      facts = @app.facter(false)
    end

    assert_equal(true, facts.class.eql?(Hash))
    assert_equal(nil, @app.facts)
  end

  def test_caching
    # NOTE: this only works if (time_to_run_facter < cache_timeout)

    assert_nothing_raised do
      @app.facter(true)
    end

    first_cached_time = @app.cache[:facter]

    assert_nothing_raised do
      @app.facter(true)
    end

    second_cached_time = @app.cache[:facter]

    assert_equal(first_cached_time, second_cached_time)

  end

  def test_cache_invalidation

    assert_nothing_raised do
      @app.facter(true)
    end

    first_cached_time = @app.cache[:facter]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      @app.facter(true)
    end

    second_cached_time = @app.cache[:facter]

    assert_not_equal(first_cached_time, second_cached_time)
    assert(second_cached_time > first_cached_time)

  end

  def test_custom_facts

    facts = nil

    assert_nothing_raised do
      facts = @app.facter(false, false)
    end

    assert_equal(true, facts.class.eql?(Hash))

    # need to come up with definitive test to not include custom facts, unsure how exactly we should do this

  end

  def teardown
    # noop
  end

end
