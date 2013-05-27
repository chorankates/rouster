require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

# this is based on RHEL output, how cross compatible is this?

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup

    @app = Rouster.new(:name => 'app')

  end

  def test_readable_by_all
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_u
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_g
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_o
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writable_by_all
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writable_by_u
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writable_by_g
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writable_by_o
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_all
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_u
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_g
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_o
    str = ''

    expectation = { }

    res = @app.parse_ls_string(str)

    assert_equal(expectation, res)
  end



  def test_errors

  end

  def teardown
    # noop
  end

end
