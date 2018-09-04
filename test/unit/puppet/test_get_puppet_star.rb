require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

# this is technically a unit test, no need for a real Rouster VM

class TestGetPuppetStar < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :unittest => true)
    end

    # expose private methods
    Rouster.send(:public, *Rouster.protected_instance_methods)
  end

  def test_happy_27_get_errors

    output = "[1;35merr: Could not retrieve catalog from remote server: Error 400 on SERVER: no result for [api_vip] in Hiera (YAML/CMS)[0m\nfizzybang\n[1;35merr: Could not retrieve catalog from remote server: Error 400 on SERVER: no result for [foobar] in Hiera (YAML/CMS)[0m"
    @app.ssh_stderr.push(output)

    assert_not_nil(@app.get_puppet_errors())
    assert_equal(2, @app.get_puppet_errors().size)
    assert_equal(@app.get_puppet_errors(), @app.get_puppet_errors(output)) # tests that passed args is same as derived

    assert_nil(@app.get_puppet_notices())
  end

  def test_happy_27_get_notices

    output = "[0;36mnotice: Not using cache on failed catalog[0m\nfizzbang\n[0;36mnotice: Not using cache on failed catalog[0m"
    @app.ssh_stdout.push(output)

    assert_not_nil(@app.get_puppet_notices())
    assert_equal(2, @app.get_puppet_notices().size)
    assert_equal(@app.get_puppet_notices(), @app.get_puppet_notices(output))

    assert_nil(@app.get_puppet_errors())

  end

  def test_happy_30_get_errors

    output = "\e[0;32mInfo: Retrieving plugin\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/root_home.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/drac_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/sfdc-custom_facts.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/concat_basedir.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/drac_fw_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/razor_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/facter_dot_d.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/puppet_vardir.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/pe_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/oob_mac.rb\e[0m\n\e[1;31mError: Could not retrieve catalog from remote server: Error 400 on SERVER: Could not find class razor for ops-tools1-1-piab.ops.sfdc.net on node ops-tools1-1-piab.ops.sfdc.net\e[0m\n\e[1;31mWarning: Not using cache on failed catalog\e[0m\n\e[1;31mError: Could not retrieve catalog; skipping run\e[0m\n"
    @app.ssh_stderr.push(output)

    assert_not_nil(@app.get_puppet_errors())
    assert_equal(2, @app.get_puppet_errors().size)
    assert_equal(@app.get_puppet_errors(), @app.get_puppet_errors(output))

    assert_nil(@app.get_puppet_notices())
  end

  def test_happy_30_get_notices

    output = "\e[0;32mInfo: Retrieving plugin\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/root_home.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/drac_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/sfdc-custom_facts.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/concat_basedir.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/drac_fw_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/razor_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/facter_dot_d.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/puppet_vardir.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/pe_version.rb\e[0m\n\e[0;32mInfo: Loading facts in /var/lib/puppet/lib/facter/oob_mac.rb\e[0m\n\e[0;32mInfo: Caching catalog for ops-tools1-1-piab.ops.sfdc.net\e[0m\n\e[0;32mInfo: Applying configuration version '1385418175'\e[0m\n\e[mNotice: /Stage[main]/Razor::Service/Razor::Api[tag]/Exec[razor-api-tag]/returns: executed successfully\e[0m\n\e[mNotice: /Stage[main]/Razor::Service/Razor::Api[policy]/Exec[razor-api-policy]/returns: executed successfully\e[0m\n\e[mNotice: /Stage[main]/Razor::Service/Razor::Api[model]/Exec[razor-api-model]/returns: executed successfully\e[0m\n\e[mNotice: Finished catalog run in 33.76 seconds\e[0m\n"
    @app.ssh_stdout.push(output)

    assert_not_nil(@app.get_puppet_notices())
    assert_equal(4, @app.get_puppet_notices().size)
    assert_equal(@app.get_puppet_notices(), @app.get_puppet_notices(output))

    assert_nil(@app.get_puppet_errors())
  end

  def test_no_errors

    output = 'there are no errors here'
    @app.ssh_stderr.push(output)

    assert_nil(@app.get_puppet_errors())
  end

  def test_no_notices

    output = 'there are no notices here'
    @app.ssh_stdout.push(output)

    assert_nil(@app.get_puppet_notices())

  end

  def teardown
    # noop
  end

end

