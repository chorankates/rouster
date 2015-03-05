require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestRun < Test::Unit::TestCase

  def setup
    @app         = Rouster.new({:name => 'app', :verbose => 4})
    @app_no_sudo = Rouster.new({:name => 'app', :verbose => 4, :sudo => false})

    @app.up()
    @app_no_sudo.up()

    assert_equal(@app.is_available_via_ssh?, true, 'app is available via SSH')
    assert_equal(@app.is_available_via_ssh?, true, 'app_no_sudo is available via SSH')
  end

  def test_happy_path

    assert_nothing_raised do
      @app.run('ls -l')
    end

    assert_equal(0, @app.exitcode, 'got expected exit code')
    assert_not_nil(@app.get_output(), 'output is populated')
    assert_match(/^total\s\d/, @app.get_output(), 'output matches expectations')
  end

  def test_bad_exit_codes

    assert_raise Rouster::RemoteExecutionError do
      @app.run('fizzbang')
    end

    assert_not_equal(0, @app.exitcode, 'got expected non-0 exit code')
    assert_not_nil(@app.get_output(), 'output is populated')
    assert_match(/fizzbang/, @app.get_output(), 'output matches expectations')
  end

  def test_bad_custom_exit_codes

    assert_raise Rouster::RemoteExecutionError do
      @app.run('ls -l', 2)
    end

    assert_equal(0, @app.exitcode)
    assert_not_nil(@app.get_output())
    assert_match(/total/, @app.get_output())
  end

  def test_sudo_enabled

    assert_nothing_raised do
      @app.run('ls -l /root')
    end

    assert_equal(0, @app.exitcode, 'got expected exit code')
    assert_no_match(/Permission denied/i, @app.get_output(), 'output matches expectations 1of2')
    assert_match(/^total\s\d/, @app.get_output(), 'output matches expectations 2of2')
  end

  def test_sudo_disabled

    assert_raise Rouster::RemoteExecutionError do
      @app_no_sudo.run('ls -l /root')
    end

    assert_not_equal(0, @app_no_sudo.exitcode, 'got expected non-0 exit code')
    assert_match(/Permission denied/i, @app_no_sudo.get_output(), 'output matches expectations')
  end

  def teardown
    @app.suspend()
    @app_no_sudo.suspend()
  end
end