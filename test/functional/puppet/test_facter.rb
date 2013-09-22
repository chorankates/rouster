require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestFacter < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
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
