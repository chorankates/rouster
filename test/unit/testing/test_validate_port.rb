require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidatePort < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_ports = {
      'tcp' => {
        '22' => {
          :address => {
            '0.0.0.0' => 'LISTEN',
            '::' => 'LISTEN'
          }
        },
        '25' => {
          :address => {
            '127.0.0.1' => 'LISTEN',
            '::1' => 'LISTEN'
          }
        },
      },
      'udp' => {
        '161' => {
          :address => {
            '0.0.0.0' => 'you_might_not_get_it'
          }
        },
      }
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:ports] = fake_ports
    @app.facts = fake_facts
  end

  def test_positive_basic

    assert(@app.validate_port(22, { :state => 'active', :protocol => 'tcp', :address => '0.0.0.0' } ))
    assert(@app.validate_port(22, { :ensure => true } ))
    assert(@app.validate_port(22, { :proto => 'tcp' } ))
    assert(@app.validate_port(22, { :address => '0.0.0.0' } ))

    assert(@app.validate_port('22', { :ensure => true } ))

    assert(@app.validate_port(161, { :state => 'absent' } ))
    assert(@app.validate_port(161, { :protocol => 'udp', :address => '0.0.0.0' } ))
    assert(@app.validate_port(161, { :proto => 'udp', :state => 'this_will_always_return_true' } ))

    assert(@app.validate_port(1234, { :exists => false } ))
    assert(@app.validate_port(1234, { :exists => 'false' } ))
    assert(@app.validate_port(1234, { :ensure => false } ))
    assert(@app.validate_port(1234, { :ensure => 'absent' } ))
    assert(@app.validate_port(1234, { :state => 'open' } ))

  end

  def test_positive_constrained

    assert(@app.validate_port(22, { :state => 'connected', :constrain => 'is_virtual true' } ))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_port(22, { :ensure => true, :address => '127.0.0.1' } ))

    assert_equal(false, @app.validate_port(22, { :ensure => true, :proto => 'udp' } ))
    assert_equal(false, @app.validate_port(22, { :ensure => true, :protocol => 'udp' } ))

    assert_equal(false, @app.validate_port(22, { :ensure => 'absent' } ))
    assert_equal(false, @app.validate_port(22, { :ensure => false } ))
    assert_equal(false, @app.validate_port(22, { :exists => 'absent' } ))
    assert_equal(false, @app.validate_port(22, { :exists => false } ))

  end

  def test_negative_constrained

    assert(@app.validate_port(22, { :ensure => false, :constrain => 'is_virtual false' } ))
    assert(@app.validate_port(22, { :ensure => true, :constrain => 'is_virtual false' } ))

  end

  def teardown
    # noop
  end

end
