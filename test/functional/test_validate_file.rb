require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateFileFunctional < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    @app = Rouster.new(:name => 'app')
  end

  def test_negative_functional_fallthrough

    assert_equal(false, @app.validate_file('/foo', {}, false, true))
    assert_equal(false, @app.validate_file('/fizzy', { :ensure => 'directory' }, false, true))
    assert_equal(false, @app.validate_file('/bang', { :ensure => 'file' }, false, true))

  end

  def teardown
    # noop
  end

end