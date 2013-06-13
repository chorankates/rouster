require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      # no reason not to do this as a passthrough once we can
      @app = Rouster.new(:name => 'app', :sudo => false)
      @app.up()
    end

    # create some temporary files
    @dir_tmp = sprintf('/tmp/rouster-%s.%s', $$, Time.now.to_i)
    @app.run("mkdir #{@dir_tmp}")

    @file_user_rwx  = sprintf('%s/user', @dir_tmp)
    @file_group_rwx = sprintf('%s/group', @dir_tmp)
    @file_other_rwx = sprintf('%s/other', @dir_tmp)
    @file_644       = sprintf('%s/sixfourfour', @dir_tmp)
    @file_755       = sprintf('%s/sevenfivefive', @dir_tmp)

    @files = [@file_user_rwx, @file_group_rwx, @file_other_rwx, @file_644, @file_755]
  end

  def test_user
    @app.run("touch #{@file_user_rwx}")
    @app.run("chmod 700 #{@file_user_rwx}")

    assert_equal(true, @app.is_readable?(@file_user_rwx,   'u'))
    assert_equal(true, @app.is_writeable?(@file_user_rwx,  'u'))
    assert_equal(true, @app.is_executable?(@file_user_rwx, 'u'))

    assert_equal(false, @app.is_readable?(@file_user_rwx,   'g'))
    assert_equal(false, @app.is_writeable?(@file_user_rwx,  'g'))
    assert_equal(false, @app.is_executable?(@file_user_rwx, 'g'))

    assert_equal(false, @app.is_readable?(@file_user_rwx,   'o'))
    assert_equal(false, @app.is_writeable?(@file_user_rwx,  'o'))
    assert_equal(false, @app.is_executable?(@file_user_rwx, 'o'))
  end

  def test_group
    @app.run("touch #{@file_group_rwx}")
    @app.run("chmod 070 #{@file_group_rwx}")

    assert_equal(false, @app.is_readable?(@file_group_rwx,   'u'))
    assert_equal(false, @app.is_writeable?(@file_group_rwx,  'u'))
    assert_equal(false, @app.is_executable?(@file_group_rwx, 'u'))

    assert_equal(true, @app.is_readable?(@file_group_rwx,   'g'))
    assert_equal(true, @app.is_writeable?(@file_group_rwx,  'g'))
    assert_equal(true, @app.is_executable?(@file_group_rwx, 'g'))

    assert_equal(false, @app.is_readable?(@file_group_rwx,   'o'))
    assert_equal(false, @app.is_writeable?(@file_group_rwx,  'o'))
    assert_equal(false, @app.is_executable?(@file_group_rwx, 'o'))
  end

  def test_other
    @app.run("touch #{@file_other_rwx}")
    @app.run("chmod 007 #{@file_other_rwx}")

    assert_equal(false, @app.is_readable?(@file_other_rwx,   'u'))
    assert_equal(false, @app.is_writeable?(@file_other_rwx,  'u'))
    assert_equal(false, @app.is_executable?(@file_other_rwx, 'u'))

    assert_equal(false, @app.is_readable?(@file_other_rwx,   'g'))
    assert_equal(false, @app.is_writeable?(@file_other_rwx,  'g'))
    assert_equal(false, @app.is_executable?(@file_other_rwx, 'g'))

    assert_equal(true, @app.is_readable?(@file_other_rwx,   'o'))
    assert_equal(true, @app.is_writeable?(@file_other_rwx,  'o'))
    assert_equal(true, @app.is_executable?(@file_other_rwx, 'o'))

  end

  def test_644
    @app.run("touch #{@file_644}")
    @app.run("chmod 644 #{@file_644}")

    assert_equal(true, @app.is_readable?(@file_644,    'u'))
    assert_equal(true, @app.is_writeable?(@file_644,   'u'))
    assert_equal(false, @app.is_executable?(@file_644, 'u'))

    assert_equal(true, @app.is_readable?(@file_644,    'g'))
    assert_equal(false, @app.is_writeable?(@file_644,  'g'))
    assert_equal(false, @app.is_executable?(@file_644, 'g'))

    assert_equal(true, @app.is_readable?(@file_644,    'o'))
    assert_equal(false, @app.is_writeable?(@file_644,  'o'))
    assert_equal(false, @app.is_executable?(@file_644, 'o'))
  end

  def test_755
    @app.run("touch #{@file_755}")
    @app.run("chmod 755 #{@file_755}")

    assert_equal(true, @app.is_readable?(@file_755,   'u'))
    assert_equal(true, @app.is_writeable?(@file_755,  'u'))
    assert_equal(true, @app.is_executable?(@file_755, 'u'))

    assert_equal(true, @app.is_readable?(@file_755,   'g'))
    assert_equal(false, @app.is_writeable?(@file_755, 'g'))
    assert_equal(true, @app.is_executable?(@file_755, 'g'))

    assert_equal(true, @app.is_readable?(@file_755,   'o'))
    assert_equal(false, @app.is_writeable?(@file_755, 'o'))
    assert_equal(true, @app.is_executable?(@file_755, 'o'))
  end

  def teardown
    # noop
  end

end
