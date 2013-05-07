require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'test/unit'

class TestRun < Test::Unit::TestCase

  def setup
    @app = Rouster.new({:name => 'app'})
    @ppm = Rouster.new({:name => 'ppm', :sudo => false})

    @app.up()
    @ppm.up()
  end

  def test_happy_path
    res = @app.run('ls -l')

    assert_equal(0, @app.exitcode, 'got expected exit code')
    assert_equal(res, @app.get_output(), 'return matches get_output()')
    assert_not_nil(@app.get_output(), 'output is populated')
    assert_match(/^total\s\d/, @app.get_output(), 'output matches expectations')
  end

  def test_bad_exit_codes
    res = @app.run('fizzbang')

    assert_not_equal(0, @app.exitcode, 'got expected non-0 exit code')
    assert_equal(res, @app.get_output(), 'return matches get_output()')
    assert_not_nil(@app.get_output(), 'output is populated')
    assert_match(/fizzbang/, @app.get_output(), 'output matches expectations')
  end

  def test_sudo_enabled
    res = @app.run('ls -l /root')

    assert_equal(0, @app.exitcode, 'got expected exit code')
    assert_no_match(/Permission denied/i, @app.get_output(), 'output matches expectations 1of2')
    assert_match(/^total\s\d/, @app.get_output(), 'output matches expectations 2of2')
  end

  def test_sudo_disabled
    res = @ppm.run('ls -l /root')

    assert_not_equal(0, @ppm.exitcode, 'got expected non-0 exit code')
    assert_match(/Permission denied/i, @ppm.get_output(), 'output matches expectations')
  end

  def teardown
    # TODO we should suspend instead if any test failed for triage
    @app.destroy()
    @ppm.destroy()
  end
end