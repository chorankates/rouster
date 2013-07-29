require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetPackages < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_packages()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:packages])

    res.each_key do |k|
      assert_not_nil(res[k])

      # this is not the best validation, but is not the worst either
      assert_match(/^\d+\./, res[k]) # start with a number
      assert_match(/\.(x86|i686|x86_64|noarch)$/, res[k]) # end with an arch type
    end

  end

  # TODO add some caching tests

  def teardown
    @app = nil
  end

end
