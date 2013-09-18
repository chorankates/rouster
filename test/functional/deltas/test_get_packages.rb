require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

# TODO need to figure out how to add package strings on our own for better testing (i.e. sfdc-razorpolicy-rhel-6.2-batch-1.0-17.noarch)

class TestDeltasGetPackages < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_equal(false, @app.deltas.has_key?(:packages))

    assert_nothing_raised do
      res = @app.get_packages()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:packages])

    res.each_key do |k|
      assert_not_nil(res[k])

      # this is not the best validation, but is not the worst either
      assert_match(/^\d+/, res[k]) # start with a number
    end

  end

  def test_caching_negative
    res = nil

    assert_equal(false, @app.deltas.has_key?(:packages))

    assert_nothing_raised do
      res = @app.get_packages(false)
    end

    assert_equal(Hash, res.class)
    assert_equal(false, @app.deltas.has_key?(:packages))
  end

  def teardown
    @app = nil
  end

end
