require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestIsDir < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      # no reason not to do this as a passthrough once we can
      @app = Rouster.new(:name => 'default', :sudo => false)
      @app.up()
    end

    # create some temporary files
    @dir_tmp = sprintf('/tmp/rouster-%s.%s', $$, Time.now.to_i)

    @dir_user_rwx  = sprintf('%s/user', @dir_tmp)
    @dir_group_rwx = sprintf('%s/group', @dir_tmp)
    @dir_other_rwx = sprintf('%s/other', @dir_tmp)
    @dir_644       = sprintf('%s/sixfourfour', @dir_tmp)
    @dir_755       = sprintf('%s/sevenfivefive', @dir_tmp)

    @dirs = [@dir_user_rwx, @dir_group_rwx, @dir_other_rwx, @dir_644, @dir_755]
  end

  def test_user
    @app.run("mkdir -p #{@dir_user_rwx}")
    @app.run("chmod 700 #{@dir_user_rwx}")

    assert_equal(true, @app.is_readable?(@dir_user_rwx,   'u'))
    assert_equal(true, @app.is_writeable?(@dir_user_rwx,  'u'))
    assert_equal(true, @app.is_executable?(@dir_user_rwx, 'u'))

    assert_equal(false, @app.is_readable?(@dir_user_rwx,   'g'))
    assert_equal(false, @app.is_writeable?(@dir_user_rwx,  'g'))
    assert_equal(false, @app.is_executable?(@dir_user_rwx, 'g'))

    assert_equal(false, @app.is_readable?(@dir_user_rwx,   'o'))
    assert_equal(false, @app.is_writeable?(@dir_user_rwx,  'o'))
    assert_equal(false, @app.is_executable?(@dir_user_rwx, 'o'))
  end

  def test_group
    @app.run("mkdir -p #{@dir_group_rwx}")
    @app.run("chmod 070 #{@dir_group_rwx}")

    assert_equal(false, @app.is_readable?(@dir_group_rwx,   'u'))
    assert_equal(false, @app.is_writeable?(@dir_group_rwx,  'u'))
    assert_equal(false, @app.is_executable?(@dir_group_rwx, 'u'))

    assert_equal(true, @app.is_readable?(@dir_group_rwx,   'g'))
    assert_equal(true, @app.is_writeable?(@dir_group_rwx,  'g'))
    assert_equal(true, @app.is_executable?(@dir_group_rwx, 'g'))

    assert_equal(false, @app.is_readable?(@dir_group_rwx,   'o'))
    assert_equal(false, @app.is_writeable?(@dir_group_rwx,  'o'))
    assert_equal(false, @app.is_executable?(@dir_group_rwx, 'o'))
  end

  def test_other
    @app.run("mkdir -p #{@dir_other_rwx}")
    @app.run("chmod 007 #{@dir_other_rwx}")

    assert_equal(false, @app.is_readable?(@dir_other_rwx,   'u'))
    assert_equal(false, @app.is_writeable?(@dir_other_rwx,  'u'))
    assert_equal(false, @app.is_executable?(@dir_other_rwx, 'u'))

    assert_equal(false, @app.is_readable?(@dir_other_rwx,   'g'))
    assert_equal(false, @app.is_writeable?(@dir_other_rwx,  'g'))
    assert_equal(false, @app.is_executable?(@dir_other_rwx, 'g'))

    assert_equal(true, @app.is_readable?(@dir_other_rwx,   'o'))
    assert_equal(true, @app.is_writeable?(@dir_other_rwx,  'o'))
    assert_equal(true, @app.is_executable?(@dir_other_rwx, 'o'))

  end

  def test_644
    @app.run("mkdir -p #{@dir_644}")
    @app.run("chmod 644 #{@dir_644}")

    assert_equal(true, @app.is_readable?(@dir_644,    'u'))
    assert_equal(true, @app.is_writeable?(@dir_644,   'u'))
    assert_equal(false, @app.is_executable?(@dir_644, 'u'))

    assert_equal(true, @app.is_readable?(@dir_644,    'g'))
    assert_equal(false, @app.is_writeable?(@dir_644,  'g'))
    assert_equal(false, @app.is_executable?(@dir_644, 'g'))

    assert_equal(true, @app.is_readable?(@dir_644,    'o'))
    assert_equal(false, @app.is_writeable?(@dir_644,  'o'))
    assert_equal(false, @app.is_executable?(@dir_644, 'o'))
  end

  def test_755
    @app.run("mkdir -p #{@dir_755}")
    @app.run("chmod 755 #{@dir_755}")

    assert_equal(true, @app.is_readable?(@dir_755,   'u'))
    assert_equal(true, @app.is_writeable?(@dir_755,  'u'))
    assert_equal(true, @app.is_executable?(@dir_755, 'u'))

    assert_equal(true, @app.is_readable?(@dir_755,   'g'))
    assert_equal(false, @app.is_writeable?(@dir_755, 'g'))
    assert_equal(true, @app.is_executable?(@dir_755, 'g'))

    assert_equal(true, @app.is_readable?(@dir_755,   'o'))
    assert_equal(false, @app.is_writeable?(@dir_755, 'o'))
    assert_equal(true, @app.is_executable?(@dir_755, 'o'))
  end

  def teardown
    @app.run(sprintf('rm -r %s', @dir_tmp))
  end

end
