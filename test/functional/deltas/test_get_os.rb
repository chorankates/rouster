require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

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

  def teardown; end # NOOP

  def test_happy_path

    assert_not_nil(@app.os_type, sprintf('unable to determine vm[%s] OS', @app))

    assert_nothing_raised do
      @app.get_services
    end

  end

  def test_unhappy_path
    # move the flag file out of the way
    # TODO should we move these out to constants? probably
    flag_files = {
      :ubuntu  => '/etc/os-release', # debian too
      :solaris => '/etc/release',
      :redhat  => '/etc/redhat-release', # centos too
      :osx     => '/System/Library/CoreServices/SystemVersion.plist',
    }

    # TODO need to assert that .run() is called
    flag_files.each_pair do |_os, ff|
      if @app.is_file?(ff)
        @app.run(sprintf('mv %s %s.bkup', ff, ff))
      end
    end

    assert_equal(:invalid, @app.os_type, sprintf('got wrong value for unmarked OS[%s]', @app.os_type))

    e = assert_raise do
        @app.get_services
    end

    assert_equal(Rouster::InternalError, e.class, sprintf('wrong exception raised[%s] [%s]', e.class, e.message))

    # TODO need to asser that .run() is called
    # put the flag file back in place
    flag_files.each_pair do |_os, ff|
      bkup = sprintf('%s.bkup', ff)
      if @app.is_file?(bkup)
        @app.run(sprintf('mv %s %s', bkup, ff))
      end
    end

  end

end