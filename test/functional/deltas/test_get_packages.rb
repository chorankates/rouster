require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

# TODO need to figure out how to add package strings on our own for better testing (i.e. sfdc-razorpolicy-rhel-6.2-batch-1.0-17.noarch)

class TestDeltasGetPackages < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 10)
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_equal(false, @app.deltas.has_key?(:packages))

    assert_nothing_raised do
      res = @app.get_packages()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:packages])

    res.each_key do |k|
      assert_not_nil(res[k])

      if res[k].is_a?(Array)
        res[k].each do |l|
          assert(l.has_key?(:arch))
          assert(l.has_key?(:version))
          assert_match(/^\d+/, res[k][l][:version]) unless @app.os_type.eql?(:rhel) # see gpg-pubkey
        end
      else
        assert(res[k].has_key?(:arch))
        assert(res[k].has_key?(:version))
        assert_match(/^\d+/, res[k][:version]) unless @app.os_type.eql?(:rhel) # start with a number
      end

    end

  end

  def test_caching_negative
    res = nil

    assert_equal(false, @app.deltas.has_key?(:packages))

    assert_nothing_raised do
      res = @app.get_packages(false)
    end

    assert_equal(Hash, res.class)
    assert_equal(false, @app.deltas.has_key?(:packages))
  end

  def test_without_deep_inspection
    res = nil

    assert_nothing_raised do
      res = @app.get_packages(true, false)
    end

    # RHEL processing doesn't do anything different in deep/not-deep calls
    if ! @app.os_type.eql?(:redhat)
      res.each_key do |k|
        assert_not_nil(res[k])
        assert_match(/\?/, res[k])
      end
    end

  end

  def test_happy_path_cache_invalidation
    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_packages(true, false)
    end

    first_cache_time = @app.cache[:packages]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_packages(true, false)
    end

    second_cache_time = @app.cache[:packages]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)
    assert(second_cache_time > first_cache_time)

  end

  def test_arch_determination
    after, install = nil, nil

    packages = [ 'glibc-2.12-1.132.el6_5.4.x86_64', 'glibc-2.12-1.132.el6_5.4.i686' ]
    install  = @app.run(sprintf('yum install -y %s', packages.join(' '))) # TODO these are already in the base, but just to be safe
    after    = @app.get_packages(false, true)

    assert(after.has_key?('glibc'))
    assert(after['glibc'].is_a?(Array))
    assert_equal(after['glibc'].length, 2)
    assert_not_equal(after['glibc'][0][:arch], after['glibc'][1][:arch])
  end

  def teardown
    @app = nil
  end

end
