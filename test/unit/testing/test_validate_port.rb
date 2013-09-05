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
      "tcp" => {
        "22" => {
          :address => {
            "0.0.0.0" => "LISTEN",
            "::"=>"LISTEN"
          }
        },
        "25" => {
          :address => {
            "127.0.0.1" => "LISTEN",
            "::1" => "LISTEN"
          }
        },
      },
      "udp" => {
        "161" => {
          :address => {
            "0.0.0.0" => "you_might_not_get_it"
          }
        },
      }
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:ports] = fake_ports
    @app.facts = fake_facts
  end

  def test_positive_basic

    #assert(@app.validate_package('abrt', { :ensure => true, :version => '2.0.8-15.el6.centos.x86_64' } ))
    #assert(@app.validate_package('abrt', { :ensure => 'present' } ))
    #assert(@app.validate_package('abrt', { :exists => true } ))
    #assert(@app.validate_package('abrt', { :version => '> 1.0'} ))

    #assert(@app.validate_package('usermode', { :version => '1.102-3' } ))
    #assert(@app.validate_package('usermode', { :version => '> 0.5' } )) # specifying 1 here fails because 1.102-3.to_i is 1
    #assert(@app.validate_package('usermode', { :version => '!= false' } ))
    #assert(@app.validate_package('usermode', { :version => '< 5.0' } ))

    #assert(@app.validate_package('hds', { :exists => false } ))
    #assert(@app.validate_package('hds', { :ensure => 'absent'}))

  end

  def test_positive_constrained

    #assert(@app.validate_package('abrt', { :ensure => true, :constrain => 'is_virtual true' } ))

  end

  def test_negative_basic

    #assert_equal(false, @app.validate_package('abrt', { :version => 'foo.bar'} ))
    #assert_equal(false, @app.validate_package('abrt', { :ensure => 'absent' } ))
    #assert_equal(false, @app.validate_package('abrt', { :exists => false } ))

  end

  def test_negative_constrained

    #assert(@app.validate_package('abrt', { :ensure => false, :constrain => 'is_virtual false' }))
    #assert(@app.validate_package('abrt', { :ensure => true,  :constrain => 'is_virtual false' }))

  end

  def teardown
    # noop
  end

end