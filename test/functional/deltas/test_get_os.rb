require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateFileFunctional < Test::Unit::TestCase

  # TODO this should probably be further abstracted into the implementation, but this is fine for now
  FLAG_FILES = {
    :ubuntu  => '/etc/os-release', # debian too
    :solaris => '/etc/release',
    :redhat  => '/etc/redhat-release', # centos too
    :osx     => '/System/Library/CoreServices/SystemVersion.plist',
  }

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    @app = Rouster.new(:name => 'app')
  end

  def teardown
    # put the flag file back in place
    FLAG_FILES.each_pair do |_os, ff|
      bkup = sprintf('%s.bkup', ff)
      if @app.is_file?(bkup)
        @app.run(sprintf('mv %s %s', bkup, ff))
      end
    end
  end

  def test_happy_path

    type = @app.os_type
    assert_not_nil(type, sprintf('unable to determine vm[%s] OS', @app))
    assert_not_equal(:invalid, type)

    assert_nothing_raised do
      @app.get_services
    end

  end

  def test_unhappy_path
    # move the flag file out of the way
    FLAG_FILES.each_pair do |_os, ff|
      if @app.is_file?(ff)
        @app.run(sprintf('mv %s %s.bkup', ff, ff))
      end
    end

    type = @app.os_type

    assert_equal(:invalid, type, sprintf('got wrong value for unmarked OS[%s]', type))

    e = assert_raise do
        @app.get_services
    end

    assert_equal(Rouster::InternalError, e.class, sprintf('wrong exception raised[%s] [%s]', e.class, e.message))

  end

end