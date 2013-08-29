require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestCaching < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.protected_instance_methods)
  end

  def test_caching_positive
    timeout = 20
    app     = Rouster.new(:name => 'app', :cache_timeout => timeout)

    assert_equal(app.cache_timeout, timeout)

    # TODO add testing for is_available_via_ssh?
    status_orig = app.status()

    assert_not_nil(app.cache[:status])
    status_orig_time = app.cache[:status][:time]

    status_new = app.status()
    status_new_time = app.cache[:status][:time]

    assert_equal(status_orig, status_new)
    assert_equal(status_orig_time, status_new_time)

    status_orig = app.status()
    status_orig_time = app.cache[:status][:time]
    sleep(timeout + 1)

    status_new = app.status()
    status_new_time = app.cache[:status][:time]

    assert_not_equal(status_orig_time, status_new_time)

  end

  def teardown
    # noop
  end

end
