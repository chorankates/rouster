require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetGroups < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 10)
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nothing_raised do
      res = @app.get_groups()
    end

    assert_equal(Hash, res.class)
    assert_not_nil(@app.deltas[:groups])

    res.each_key do |k|
      assert_not_nil(res[k][:users])
      assert_equal(res[k][:users].class, Array)
      assert_not_nil(res[k][:gid])
    end

    ## only working on *nix right now, check some specific accounts
    expected = %w[root vagrant]

    expected.each do |e|
      assert_not_nil(res[e])
    end

  end

  def test_without_caching
    old_groups, new_groups = nil, nil

    assert_nothing_raised do
      old_groups = @app.get_groups(false)
    end

    assert_nil(@app.deltas[:groups])

    new_group = sprintf('rouster-%s', Time.now.to_i)

    ## create a group here
    if @app.os_type.eql?(:rhel)
      @app.run(sprintf('groupadd %s', new_group))
    else
      omit('only doing group creation on RHEL hosts')
    end

    assert_nothing_raised do
      new_groups = @app.get_groups(false)
    end

    assert_nil(@app.deltas[:groups])
    assert_not_nil(new_groups[new_group])
    assert_not_equal(old_groups, new_groups)

  end

  def test_deep_inspection
    deep, shallow = nil, nil

    assert_nothing_raised do
      deep    = @app.get_groups(false, true)
      shallow = @app.get_groups(false, false)
    end

    assert_not_equal(deep, shallow)

    ## this is not really the best test
    deep_none, shallow_none = 0, 0

    deep.each_key do |group|
      deep_none += 1 if deep[group][:users][0].eql?('NONE')
    end

    shallow.each_key do |group|
      shallow_none += 1 if shallow[group][:users][0].eql?('NONE')
    end

    assert(shallow_none > deep_none)
  end

  def test_happy_path_cache_invalidation
    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_groups(true, false)
    end

    first_cache_time = @app.cache[:groups]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_groups(true, false)
    end

    second_cache_time = @app.cache[:groups]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)

  end

  def teardown
    @app = nil
  end

end
