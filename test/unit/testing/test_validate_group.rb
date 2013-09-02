require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateGroup < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_groups = {
      'root' => {
        :gid   => 0,
        :users => ['root', 'conor']
      },
      'foo' => {
        :gid   => '10',
        :users => ['foo']
      }
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:groups] = fake_groups
    @app.facts = fake_facts
  end

  def test_positive_basic

    assert(@app.validate_group('root', { :gid => 0, :users => ['root', 'conor'] } ))
    assert(@app.validate_group('root', { :gid => '0', :ensure => 'present' } ))
    assert(@app.validate_group('root', { :exists => true } ))
    assert(@app.validate_group('root', { :user => 'conor' } ))
    assert(@app.validate_group('root', { :users => ['conor']} ))

    assert(@app.validate_group('toor', { :exists => false } ))
    assert(@app.validate_group('toor', { :ensure => 'absent' } ))

  end

  def test_positive_constrained

    assert(@app.validate_group('root', { :gid => 0 , :constrain => 'is_virtual true'} ))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_group('root', { :gid => 10 } ))
    assert_equal(false, @app.validate_group('root', { :ensure => 'absent'} ))
    assert_equal(false, @app.validate_group('root', { :gid => 0, :users => ['root', 'toor'] } ))
    assert_equal(false, @app.validate_group('root', { :gid => 0, :users => 'toor' }))

  end

  def test_negative_constrained

    assert(@app.validate_group('root', { :gid => 10, :constrain => 'is_virtual false'} ))

  end

  def teardown
    # noop
  end

end
