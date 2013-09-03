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
  end

  def test_positive_basic

    assert(@app.validate_file('/etc/hosts', { :ensure => 'file', :mode => '0644', :file => true, :directory => false,  :owner => 'root', :group => 'root' }, true))
    assert(@app.validate_file('/etc/hosts', { :exists => 'present' }, true ))
    assert(@app.validate_file('/etc/hosts', { }, true ))
    assert(@app.validate_file('/etc/hosts', { :mode => '0644' }, true))
    assert(@app.validate_file('/etc/hosts', { :permissions => '0644' }, true))
    assert(@app.validate_file('/etc/hosts', { :size => 166 }, true ))
    assert(@app.validate_file('/etc/hosts', { :size => '166' }, true ))
    assert(@app.validate_file('/etc/hosts', { :file => 'true' }, true))
    assert(@app.validate_file('/etc/hosts', { :file => true }, true))
    assert(@app.validate_file('/etc/hosts', { :directory => 'false' }, true))
    assert(@app.validate_file('/etc/hosts', { :directory => false }, true))
    assert(@app.validate_file('/etc/hosts', { :owner => 'root' }, true))
    assert(@app.validate_file('/etc/hosts', { :group => 'root' }, true))

    # TODO figure out how to run these in a truly unit-y way, since the data is not present in faked hash, we will fall through to functional testing
    #assert(@app.validate_file('/etc/fizzbang', { :ensure => 'absent' }, true))
    #assert(@app.validate_file('/etc/fizzbang', { :ensure => false }, true ))

    assert(@app.validate_file('/etc', { :ensure => 'directory' }, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir' }, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :file => 'false' }, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :directory => 'true' }, true))
    assert(@app.validate_file('/etc', { :ensure => 'dir', :file => 'false', :directory => 'true' }, true))

    # TODO figure out how to run these in a truly unity-y way, since the data is not present in faked hash, we will fall through to functional testing
    #assert(@app.validate_file('/fizzy', { :ensure => 'absent' }, true))
    #assert(@app.validate_file('/fizzy', { :ensure => false }, true))
    #assert(@app.validate_file('/fizzy', { :exists => 'false' }, true))
    #assert(@app.validate_file('/fizzy', { :exists => false }, true))

    # TODO need to do :contains testing in a non-unit context

  end

  def test_positive_constrained

    assert(@app.validate_file('/etc/hosts', { :mode => '0644', :constrain => 'is_virtual true' }, true))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_file('/etc/hosts', { :mode => '0777' }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :permissions => '0777' }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :file => 'false' }, true ))
    assert_equal(false, @app.validate_file('/etc/hosts', { :file => false }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :directory => 'true' }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :directory => true }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => 'foo' }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => 100 }, true))
    assert_equal(false, @app.validate_file('/etc/hosts', { :size => '100'}, true))

    # TODO figure out how to run these in a truly unit-y way, since the data is not present in faked hash, we will fall through to functional testing
    #assert_equal(false, @app.validate_file('/foo', {}, true))
    #assert_equal(false, @app.validate_file('/fizzy', { :ensure => 'directory' }, true))
    #assert_equal(false, @app.validate_file('/bang', { :ensure => 'file' }, true))

  end

  def test_negative_constrained

    assert(@app.validate_file('/etc/hosts', { :mode => '0644', :constrain => 'is_virtual false' }, true))
    assert(@app.validate_file('/etc/hosts', { :mode => '0999', :constrain => 'is_virtual false' }, true))

  end

  def teardown
    # noop
  end

end