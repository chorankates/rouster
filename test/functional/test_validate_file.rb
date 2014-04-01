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

  def test_happy_basic
    # TODO expand this.. considerably
    file        = '/tmp/chiddy'
    expectation = { :ensure => 'file' }

    @app.run("touch #{file}")

    assert_equal(true, @app.validate_file(file, expectation, false, true))

  end

  def test_happy_doesnt_contain
    file         = '/etc/hosts'
    expectations = {
      :ensure        => 'file',
      :doesntcontain => 'fizzybang.12345',
      :notcontains   => 'this.isnt.there.either'
    }

    expectations.each do |e|
      assert_equal(true, @app.validate_file(file, e, false, true))
    end

  end

  def test_happy_symlink
    file = '/tmp/bang'

    @app.run("ln -sf /etc/hosts #{file}")

    expectations = [
      { :ensure => 'symlink' },
      { :ensure => 'link' },
      { :ensure => 'link', :target => '/etc/hosts' }
    ]

    expectations.each do |e|
      # this is a weird convention, maybe reconsider the calling signature for validate_file
      #    thinking something like validate_file(expectations) instead of validate_file(file, expectations)
      assert_equal(true, @app.validate_file(file, e, false, true))
    end

  end

  def teardown
    # noop
  end

end