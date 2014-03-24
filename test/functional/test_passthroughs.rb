require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

# most of the real passthrough testing is done in test_new.rb, since the only effective difference should be the target of the SSH connection

class TestPassthroughs < Test::Unit::TestCase

  def setup
    # noop
  end

  def test_functional_local_passthrough

    @local = Rouster.new(
      :name => 'local',
      :passthrough => {
        :type => :local,
      },
    )

    assert(@local.is_passthrough?(), 'worker is a passthrough')
    assert(@local.is_available_via_ssh?(), 'worker is available via SSH')

    # put a file in /tmp/fizz and read it back
    tmpfile = sprintf('/tmp/fizzy.%s.%s', Time.now.to_i, $$)
    content = 'this is some sample text'

    assert_nothing_raised do
      @local.run("echo #{content} >> #{tmpfile}")
    end

    read = @local.run("cat #{tmpfile}")

    assert_equal(content, read, 'worker is able to read and write files on system')

    # TODO better here
    assert_nothing_raised do
      @local.file('/etc/hosts')
      @local.dir('/tmp')
    end

  end

  def test_functional_remote_passthrough

    @remote = Rouster.new(
      :name => 'remote',
      :passthrough => {
        :type => :remote,
        :host => '127.0.0.1',
        :user => ENV['USER'],
        key   => sshkey,
      }
    )

    assert_equal('remote', @app.name)
    assert_equal(true, @app.is_passthrough?())
    assert_equal(false, @app.uses_sudo?())
    assert_equal(true, @app.is_available_via_ssh?())

    # TODO better here
    assert_nothing_raised do
      @local.file('/etc/hosts')
      @local.dir('/tmp')
    end

  end

  def teardown
    # noop
  end

end
