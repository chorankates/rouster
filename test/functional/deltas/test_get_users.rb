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

  def happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_users()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:users])
  end

  # TODO add some caching tests

  def teardown
    # noop
  end

end
