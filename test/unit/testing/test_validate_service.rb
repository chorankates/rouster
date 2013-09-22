require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateService < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_services = {
      'openssh-daemon' => 'running',
      'ntpd'           => 'stopped',
      'puppet'         => 'stopped'
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:services] = fake_services
    @app.facts = fake_facts
  end

  def test_positive_basic

    assert(@app.validate_service('ntpd', { :exists => true, :state => 'stopped' } ))
    assert(@app.validate_service('ntpd', { :exists => 'true' } ))
    assert(@app.validate_service('ntpd', { :ensure => 'present' } ))
    assert(@app.validate_service('ntpd', { :ensure => true } ))

    assert(@app.validate_service('openssh-daemon', { :status => 'running' } ))

    assert(@app.validate_service('sshd', { :exists => 'false' } ))
    assert(@app.validate_service('sshd', { :exists => false } ))
    assert(@app.validate_service('sshd', { :ensure => 'absent' } ))
    assert(@app.validate_service('sshd', { :ensure => false } ))

  end

  def test_positive_constrained

    assert(@app.validate_service('ntpd', { :status => 'stopped', :constrain => 'is_virtual true' } ))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_service('openssh-daemon', { :status => 'stopped' } ))
    assert_equal(false, @app.validate_service('sshd', {} ))

    assert_equal(false, @app.validate_service('ntpd', { :ensure => 'absent' } ))
    assert_equal(false, @app.validate_service('ntpd', { :ensure => false } ))
    assert_equal(false, @app.validate_service('ntpd', { :exists => 'absent' } ))
    assert_equal(false, @app.validate_service('ntpd', { :exists => false } ))

  end

  def test_negative_constrained

    assert(@app.validate_service('fizzy', { :status => 'stopped', :constrain => 'is_virtual false' } ))
    assert(@app.validate_service('ntpd',  { :state => 'stopped', :constrain => 'is_virtual false' } ))

  end

  def teardown
    # noop
  end

end
