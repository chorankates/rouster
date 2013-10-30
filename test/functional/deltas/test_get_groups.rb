require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetGroups < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
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
    if @app.os_type.eql?(:redhat)
      @app.run(sprintf('groupadd %s', new_group))
    else
      skip('only doing group creation on RHEL hosts')
    end

    assert_nothing_raised do
      new_groups = @app.get_groups(false)
    end

    assert_nil(@app.deltas[:groups])
    assert_not_nil(new_groups[new_group])
    assert_not_equal(old_groups, new_groups)

  end

  # TODO add some handling for deep tests

  def teardown
    # noop
    #@app = nil
  end

end
