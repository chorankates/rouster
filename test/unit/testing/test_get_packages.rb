require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestFunctionalGetPackages < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    @app = Rouster.new(:name => 'app', :unittest => true)

  end

  def test_rhel_default
    @app.instance_variable_set(:@ostype, :redhat)
    services = {}

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-service_status-all', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(:false, :true, :default, raw)
    end

    expected = {
      'acpid'      => 'running', # acpid (pid  945) is running...
      'ip6tables'  => 'stopped', # ip6tables: Firewall is not running.
      'Kdump'      => 'stopped', # Kdump is not operational
      'mdmonitor'  => 'stopped', # mdmonitor is stopped
      'netconsole' => 'stopped', # netconsole module not loaded
    }

    expected.each_pair do |service,state|
      assert(services.has_key?(service), "service[#{service}]")
      assert_equal(services[service], state, "service[#{service}] state[#{state}]")
    end

  end

  def test_rhel_upstart
    @app.instance_variable_set(:@ostype, :redhat)
    services = {}

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-initctl_list', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(:false, :true, :upstart, raw)
    end

    expected = {
      'rc'    => 'stopped', # rc stop/waiting
      'named' => 'running', # named start/running, process 8959
      'tty'   => 'running', # tty (/dev/tty3) start/running, process 1601
    }

    expected.each_pair do |service,state|
      assert(services.has_key?(service), "service[#{service}]")
      assert_equal(services[service], state, "service[#{service}] state[#{state}]")
    end

  end

  def test_osx_default
    @app.instance_variable_set(:@ostype, :osx)
    services = {}

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/osx-launchctl_list', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(:false, :true, :default, raw)
    end

    expected = {
      'com.bigfix.BESAgent'            => 'running', # 100	-	com.bigfix.BESAgent
      'com.trendmicro.mpm.icore.agent' => 'stopped', # -	0	com.trendmicro.mpm.icore.agent
    }

    expected.each_pair do |service,state|
      assert(services.has_key?(service), "service[#{service}]")
      assert_equal(services[service], state, "service[#{service}] state[#{state}]")
    end

  end

  def teardown
    # noop
  end

end
