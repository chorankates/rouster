require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestUnitGetPackages < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    @app = Rouster.new(:name => 'app', :unittest => true, :verbosity => 4)

  end

  def test_rhel_systemv
    @app.instance_variable_set(:@ostype, :redhat)
    services = {}

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-systemv', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(false, true, :systemv, raw)
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

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-upstart', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(false, true, :upstart, raw)
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

  def test_rhel_both
    @app.instance_variable_set(:@ostype, :redhat)
    services = {}

    systemv_contents  = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-systemv', File.dirname(File.expand_path(__FILE__))))
    upstart_contents = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-upstart', File.dirname(File.expand_path(__FILE__))))

    # TODO this isn't a great test, because the implementation will never have both outputs in the same control loop
    raw = systemv_contents
    raw << upstart_contents

    assert_nothing_raised do
      services = @app.get_services(false, true, :all, raw)
    end

    expected = {
      'acpid' => 'running', # initd
      'cgred' => 'stopped', # initd
      'named' => 'running', # upstart
      # 'rc'    => 'stopped', # upstart -- this is getting mishandled, see comment on line #74 and test_rhel_both_real for reasons this doesn't matter
    }

    expected.each_pair do |service,state|
      assert(services.has_key?(service), "service[#{service}]")
      assert_equal(services[service], state, "service[#{service}] state[#{state}]}")
    end

  end

  def test_rhel_both_real
    @app.instance_variable_set(:@ostype, :redhat)
    services = {}

    systemv_contents  = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-systemv', File.dirname(File.expand_path(__FILE__))))
    upstart_contents = File.read(sprintf('%s/../../../test/unit/testing/resources/rhel-upstart', File.dirname(File.expand_path(__FILE__))))

    expected = {
        'acpid' => 'running', # initd
        'cgred' => 'stopped', # initd
        'named' => 'running', # upstart
        'rc'    => 'stopped', # upstart
    }

    assert_nothing_raised do
      systemv = @app.get_services(false, true, :systemv, systemv_contents)
      upstart = @app.get_services(false, true, :upstart, upstart_contents)

      services = systemv.merge(upstart) # TODO how do we ensure merge order doesn't mislead us?
    end

    expected.each_pair do |service,state|
      assert(services.has_key?(service), "service[#{service}]")
      assert_equal(services[service], state, "service[#{service}] state[#{state}]}")
    end


  end

  def test_osx_launchd
    @app.instance_variable_set(:@ostype, :osx)
    services = {}

    raw = File.read(sprintf('%s/../../../test/unit/testing/resources/osx-launchd', File.dirname(File.expand_path(__FILE__))))

    assert_nothing_raised do
      services = @app.get_services(false, true, :launchd, raw)
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
