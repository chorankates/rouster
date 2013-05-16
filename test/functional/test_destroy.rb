require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    @app.up()
    assert_equal(@app.is_available_via_ssh?(), true)
  end

  def test_happy_path

    assert_equal(@app.status(), 'running')

    assert_nothing_raised do
      @app.destroy()
    end

    assert_equal(false, @app.is_available_via_ssh?)
    assert_equal('not_created', @app.status())
  end

  def test_thats_what_we_call_overkill
    assert_equal(@app.status(), 'running')

    assert_nothing_raised do
      @app.destroy()
    end

    assert_equal(false, @app.is_available_via_ssh?)
    assert_equal('not_created', @app.status())

    assert_nothing_raised do
      @app.destroy()
    end

    assert_equal('not_created', @app.status())

  end

  def test_bad_object
    # this isn't really a valid test, we're catching the exception thrown in instantiation, not up

    assert_raise Rouster::InternalError do
      bad = Rouster.new(:name => 'this_vm_dne')
      bad.destroy()
    end

  end

  def teardown
    # noop
  end

end
