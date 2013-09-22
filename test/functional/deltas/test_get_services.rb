require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetServices < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()

    # eventually this should be standardized (and symbolized?)
    @allowed_states = %w(exists operational running stopped)
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
    end

  end

  # TODO add some caching tests

  def teardown
    @app = nil
  end

end
