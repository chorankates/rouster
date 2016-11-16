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

  def teardown
    # put the flag file back in place
    Rouster.os_files.each_pair do |_os, ff|
      [ ff ].flatten.each do |f|
        bkup = sprintf('%s.bkup', f)
        if @app.is_file?(bkup)
          @app.run(sprintf('mv %s %s', bkup, f))
        end
      end
    end
  end

  def test_happy_path

    type = @app.os_type
    assert_not_nil(type, sprintf('unable to determine vm[%s] OS', @app))
    assert_not_equal(:invalid, type)

    version = @app.os_version(type)
    assert_not_nil(version, sprintf('unable to determine vm[%s] OS version', @app))
    assert_not_equal(:invalid, version)

    assert_nothing_raised do
      @app.get_services
    end

  end

  def test_unhappy_path
    # move the flag file out of the way
    Rouster.os_files.each_pair do |_os, ff|
      [ ff ].flatten.each do |f|
        if @app.is_file?(ff)
          @app.run(sprintf('mv %s %s.bkup', f, f))
        end
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