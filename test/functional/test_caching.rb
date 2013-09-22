require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestCaching < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.protected_instance_methods)
  end

  def test_status_caching
    timeout = 5
    app     = Rouster.new(:name => 'app', :cache_timeout => timeout)

    assert_equal(app.cache_timeout, timeout)

    status_orig = app.status()

    assert_not_nil(app.cache[:status])
    status_orig_time = app.cache[:status][:time]

    assert_equal(status_orig, app.cache[:status][:status])

    status_new = app.status()
    status_new_time = app.cache[:status][:time]

    assert_equal(status_orig, status_new)
    assert_equal(status_orig_time, status_new_time)

    app.status()
    status_orig_time = app.cache[:status][:time]
    sleep(timeout + 1)

    app.status()
    status_new_time = app.cache[:status][:time]

    assert_not_equal(status_orig_time, status_new_time)

  end

  def test_status_caching_functional
    timeout = 5
    app     = Rouster.new(:name => 'app', :cache_timeout => timeout)

    status_orig = app.status()
    status_orig_time = app.cache[:status][:time]

    if status_orig.eql?('running')
      app.suspend()
    elsif status_orig.eql?('not created')
      app.up()
    else
      # should just be suspended/saved
      app.destroy()
    end

    sleep(timeout) # this is almost certainly unnecessary, given the amount of time the above operations take, but just being safe

    status_new = app.status()
    status_new_time = app.cache[:status][:time]

    assert_not_equal(status_orig, status_new)
    assert_not_equal(status_orig_time, status_new_time)

  end

  def test_status_caching_negative
    app = Rouster.new(:name => 'app')

    app.status()
    assert_nil(app.cache[:status])
  end

  def test_ssh_caching
    timeout = 100
    app     = Rouster.new(:name => 'app', :sshtunnel => true, :cache_timeout => timeout)
    app.up()

    assert_equal(app.cache_timeout, timeout)

    avail_orig = app.is_available_via_ssh?
    assert_not_nil(app.cache[:is_available_via_ssh?])

    avail_orig_time = app.cache[:is_available_via_ssh?][:time]
    assert_equal(avail_orig, app.cache[:is_available_via_ssh?][:status])

    avail_new = app.is_available_via_ssh?
    avail_new_time = app.cache[:is_available_via_ssh?][:time]

    assert_equal(avail_orig, avail_new)
    assert_equal(avail_new_time, avail_orig_time)

    app.is_available_via_ssh?
    avail_orig_time = app.cache[:is_available_via_ssh?][:time]

    sleep(timeout + 1)

    app.is_available_via_ssh?
    avail_new_time = app.cache[:is_available_via_ssh?][:time]

    assert_not_equal(avail_orig_time, avail_new_time)
  end

  def test_ssh_caching_functional
    # noop
  end

  def test_ssh_caching_negative
    app = Rouster.new(:name => 'app')

    app.is_available_via_ssh?()
    assert_nil(app.cache[:is_available_via_ssh?])
  end

  def teardown
    # noop
  end

end
