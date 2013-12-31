require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetCrontab < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 20)
    end

    @app.up()

    ## setup some cronjobs so we have something to look at - and yes, this is hacktastic
    ['root', 'puppet'].each do | user|
      tmp = sprintf('/tmp/rouster.tmp.crontab.%s.%s.%s', user, Time.now.to_i, $$)
      @app.run("echo '0 0 * * * echo #{user}' > #{tmp}")
      #@app.run("crontab -u #{user} -f #{tmp}") # rhel
      @app.run("crontab -u #{user} #{tmp}") # centos
    end

  end

  def test_happy_path

    res = nil

    assert_nothing_raised do
      res = @app.get_crontab()
    end

    assert_equal(Hash, res.class)
    assert_equal(res, @app.deltas[:crontab]['root'])
    assert_not_nil(@app.deltas[:crontab]['root'])

  end

  def test_happy_path_specified_user

    res = nil

    assert_nothing_raised do
      res = @app.get_crontab('puppet')
    end

    assert_equal(Hash, res.class)
    assert_equal(res, @app.deltas[:crontab]['puppet'])
    assert_not_nil(@app.deltas[:crontab]['puppet'])

  end

  def test_happy_path_specified_star

    res = nil

    assert_nothing_raised do
      res = @app.get_crontab('*')
    end

    assert_equal(Hash, res.class)
    assert_equal(res, @app.deltas[:crontab])
    assert_not_nil(@app.deltas[:crontab]['root'])
    assert_not_nil(@app.deltas[:crontab]['puppet'])

  end

  def test_unhappy_path_non_existent_user

    res = nil

    assert_nothing_raised do
      res = @app.get_crontab('fizzybang')
    end

    assert_equal(Hash, res.class)
    assert_equal(0, res.keys.size)

  end

  def test_happy_path_no_cache

    res = nil

    assert_nothing_raised do
      res = @app.get_crontab('root', false)
    end

    assert_equal(Hash, res.class)
    assert_nil(@app.deltas[:crontab])

  end

  def test_happy_path_cache_invalidated

    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_crontab('root', true)
    end

    first_cache_time = @app.cache[:crontab]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_crontab('root', true)
    end

    second_cache_time = @app.cache[:crontab]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)

  end

  def teardown
    @app = nil
  end

end