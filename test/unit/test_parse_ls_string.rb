require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

# this is based on RHEL output, how cross compatible is this?

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestParseLsString < Test::Unit::TestCase

  def setup

    @app = Rouster.new(:name => 'app', :unittest => true)

    def @app.exposed_parse_ls_string(*args)
      parse_ls_string(*args)
    end

  end

  def test_readable_by_all
    str = "-r--r--r-- 1 root root 199 May 27 22:51 readable\n"

    expectation = {
      :directory?  => false,
      :file?       => true,
      :mode        => '0444',
      :name        => 'readable',
      :owner       => 'root',
      :group       => 'root',
      :size        => '199',
      :executable? => [false, false, false],
      :readable?   => [true, true, true],
      :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_u
    str = "-r-------- 1 root root 199 May 27 22:51 readable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0400',
        :name        => 'readable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [true,  false, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_g
    str = "----r----- 1 root root 199 May 27 22:51 readable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0040',
        :name        => 'readable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, true, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_readable_by_o
    str = "-------r-- 1 root root 199 May 27 22:51 readable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0004',
        :name        => 'readable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, false, true],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_all
    str = "---x--x--x 1 root root 199 May 27 22:51 executable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0111',
        :name        => 'executable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [true, true, true],
        :readable?   => [false, false, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_u
    str = "---x------ 1 root root 199 May 27 22:51 executable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0100',
        :name        => 'executable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [true, false, false],
        :readable?   => [false, false, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_g
    str = "------x--- 1 root root 199 May 27 22:51 executable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0010',
        :name        => 'executable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, true, false],
        :readable?   => [false, false, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_executable_by_o
    str = "---------x 1 root root 199 May 27 22:51 executable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0001',
        :name        => 'executable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, true],
        :readable?   => [false, false, false],
        :writeable?  => [false, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writeable_by_all
    str = "--w--w--w- 1 root root 199 May 27 22:51 writeable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0222',
        :name        => 'writeable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, false, false],
        :writeable?  => [true, true, true]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writeable_by_u
    str = "--w------- 1 root root 199 May 27 22:51 writeable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0200',
        :name        => 'writeable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, false, false],
        :writeable?  => [true, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writeable_by_g
    str = "-----w---- 1 root root 199 May 27 22:51 writeable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0020',
        :name        => 'writeable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, false, false],
        :writeable?  => [false, true, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_writeable_by_o
    str = "--------w- 1 root root 199 May 27 22:51 writeable\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0002',
        :name        => 'writeable',
        :owner       => 'root',
        :group       => 'root',
        :size        => '199',
        :executable? => [false, false, false],
        :readable?   => [false, false, false],
        :writeable?  => [false, false, true]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_mix_and_match_1
    str = "-------rwx 1 vagrant vagrant 1909 May 27 22:51 able\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0007',
        :name        => 'able',
        :owner       => 'vagrant',
        :group       => 'vagrant',
        :size        => '1909',
        :executable? => [false, false, true],
        :readable?   => [false, false, true],
        :writeable?  => [false, false, true]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_mix_and_match_2
    str = "-rw-r--r--  1 vagrant  root  0 Jun 13 09:35 foo\n"

    expectation = {
        :directory?  => false,
        :file?       => true,
        :mode        => '0644',
        :name        => 'foo',
        :owner       => 'vagrant',
        :group       => 'root',
        :size        => '0',
        :executable? => [false, false, false],
        :readable?   => [true, true, true],
        :writeable?  => [true, false, false]
    }

    res = @app.exposed_parse_ls_string(str)

    assert_equal(expectation, res)
  end

  def test_dir_detection
    dir_str = "drwxrwxrwt 5 root root 4096 May 28 00:26 /tmp/\n"
    file_str  = "-rw-r--r-- 1 root    root      906 Oct  2  2012 grub.conf\n"

    dir  = @app.exposed_parse_ls_string(dir_str)
    file = @app.exposed_parse_ls_string(file_str)

    assert_equal(true,  dir[:directory?])
    assert_equal(false, dir[:file?])

    assert_equal(false, file[:directory?])
    assert_equal(true,  file[:file?])

  end

  def teardown
    # noop
  end

end
