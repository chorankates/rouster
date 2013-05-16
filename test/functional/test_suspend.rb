require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

  end

  def test_happy_path
    @app.up()

    assert_equal(true, @app.is_available_via_ssh?)

    assert_nothing_raised do
      @app.suspend()
    end

    assert_equal(false, @app.is_available_via_ssh?)
  end

  def test_bad_object
    # this isn't really a valid test, we're catching the exception thrown in instantiation, not up

    assert_raise Rouster::InternalError do
      bad = Rouster.new(:name => 'this_vm_dne')
      bad.up()
      bad.suspend()
    end

  end

  def teardown
    # noop
  end

end
