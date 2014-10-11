require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestStatus < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'default')
    end

  end

  def test_1_destroyed
    @app.destroy()

    assert_equal('not created', @app.status())
  end

  def test_2_upped
    @app.up()

    assert_equal('running', @app.status())
  end

  def test_3_suspended
    @app.up unless @app.status.eql?('running')
    @app.suspend()

    assert_equal('saved', @app.status())
  end

  def teardown
    # noop
  end

end
