require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateFile < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_files = {
      '/etc/hosts' => {
        :mode        => '0644',
        :name        => '/etc/hosts',
        :owner       => 'root',
        :group       => 'root',
        :size        => '166',
        :directory?  => false,
        :file?       => true,
        :executable? => [false, false, false],
        :writeable?  => [true, false, false],
        :readable?   => [true, true, true]
      },
      '/etc' => {
        :mode        => '0755',
        :name        => '/etc/',
        :owner       => 'root',
        :group       => 'root',
        :size        => '4096',
        :directory?  => true,
        :file?       => false,
        :executable? => [true, true, true],
        :writeable?  => [true, false, false],
        :readable?   => [true, true, true]
      }
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:files] = fake_files
    @app.facts = fake_facts

    # not quite a unit test,.
    skip unless @app.status().eql?('running')
  end

  def test_positive_basic

    assert(@app.validate_file('/etc/hosts', { :ensure => 'file', :mode => '0644', :file => true, :directory => false,  :owner => 'root', :group => 'root' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :exists => 'present' }, false, true ))
    assert(@app.validate_file('/etc/hosts', { }, false, true ))
    assert(@app.validate_file('/etc/hosts', { :mode => '0644' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :permissions => '0644' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :size => 166 }, false, true ))
    assert(@app.validate_file('/etc/hosts', { :size => '166' }, false, true ))
    assert(@app.validate_file('/etc/hosts', { :file => 'true' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :file => true }, false, true))
    assert(@app.validate_file('/etc/hosts', { :directory => 'false' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :directory => false }, false, true))
    assert(@app.validate_file('/etc/hosts', { :owner => 'root' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :group => 'root' }, false, true))

    assert(@app.validate_file('/etc/fizzbang', { :ensure => 'absent' }, false, true))
    assert(@app.validate_file('/etc/fizzbang', { :ensure => false }, false, true ))

    assert(@app.validate_file('/etc', { :ensure => 'directory' }, false, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir' }, false, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :file => 'false' }, false, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :directory => 'true' }, false, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :file => 'false', :directory => 'true' }, false, true))

    assert(@app.validate_file('/fizzy', { :ensure => 'absent' }, false, true))
    assert(@app.validate_file('/fizzy', { :ensure => false }, false, true))
    assert(@app.validate_file('/fizzy', { :exists => 'false' }, false, true))
    assert(@app.validate_file('/fizzy', { :exists => false }, false, true))

    # TODO need to do :contains testing in a non-unit context

  end

  def test_positive_constrained

    assert(@app.validate_file('/etc/hosts', { :mode => '0644', :constrain => 'is_virtual true' }, false, true))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_file('/etc/hosts', { :mode => '0777' }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :permissions => '0777' }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :file => 'false' }, false, true ))
    assert_equal(false, @app.validate_file('/etc/hosts', { :file => false }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :directory => 'true' }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :directory => true }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => 'foo' }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => 100 }, false, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => '100'}, false, true))

    # TODO figure out how to run these in a truly unit-y way, since the data is not present in faked hash, we will fall through to functional testing
    assert_equal(false, @app.validate_file('/foo', {}, false, true))
    assert_equal(false, @app.validate_file('/fizzy', { :ensure => 'directory' }, false, true))
    assert_equal(false, @app.validate_file('/bang', { :ensure => 'file' }, false, true))

  end

  def test_negative_constrained

    assert(@app.validate_file('/etc/hosts', { :mode => '0644', :constrain => 'is_virtual false' }, false, true))
    assert(@app.validate_file('/etc/hosts', { :mode => '0999', :constrain => 'is_virtual false' }, false, true))

  end

  def teardown
    # noop
  end

end