require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateUser < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_users = {
      'root' => {
        :shell       => '/bin/bash',
        :home        => '/root',
        :home_exists => true,
        :uid         => '0',
        :gid         => '0'
      },
      'bin' => {
        :shell       => '/sbin/nologin',
        :home        => '/bin',
        :home_exists => true,
        :uid         => 1,
        :gid         => 1
      },
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:users] = fake_users
    @app.facts = fake_facts
  end

  def test_positive_basic

    assert(@app.validate_user('root', { :shell => '/bin/bash', :home => '/root', :home_exists => 'true', :uid => 0, :gid => 0 } ))
    assert(@app.validate_user('root', { :shell => '/bin/bash', :ensure => 'present' } ))
    assert(@app.validate_user('root', { :exists => true } ))
    assert(@app.validate_user('root', { :home => '/root' } ))
    assert(@app.validate_user('root', { :home_exists => true } ))
    assert(@app.validate_user('root', { :uid => '0' } ))
    assert(@app.validate_user('root', { :gid => 0 } ))

    assert(@app.validate_user('toor', { :exists => 'false' } ))
    assert(@app.validate_user('toor', { :exists => false } ))
    assert(@app.validate_user('toor', { :ensure => 'absent' } ))
    assert(@app.validate_user('toor', { :ensure => false } ))

  end

  def test_positive_constrained

    assert(@app.validate_user('root', { :gid => '0', :constrain => 'is_virtual true '} ))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_user('root', { :gid => 10 } ))
    assert_equal(false, @app.validate_user('root', { :gid => '10' } ))
    assert_equal(false, @app.validate_user('root', { :uid => 10 } ))
    assert_equal(false, @app.validate_user('root', { :uid => '10' } ))

    assert_equal(false, @app.validate_user('root', { :shell => '/bin/ksh' } ))
    assert_equal(false, @app.validate_user('root', { :home => '/tmp' } ))
    assert_equal(false, @app.validate_user('root', { :home_exists => 'false' } ))
    assert_equal(false, @app.validate_user('root', { :home_exists => false } ))

    assert_equal(false, @app.validate_user('root', { :ensure => 'absent' } ))
    assert_equal(false, @app.validate_user('root', { :ensure => false } ))
    assert_equal(false, @app.validate_user('root', { :ensure => 'absent' } ))
    assert_equal(false, @app.validate_user('root', { :ensure => false } ))

  end

  def test_negative_constrained

    assert(@app.validate_user('root', { :gid => 0, :constrain => 'is_virtual false' } ))
    assert(@app.validate_user('root', { :gid => 9, :constrain => 'is_virtual false' } ))

  end

  def teardown
    # noop
  end

end
