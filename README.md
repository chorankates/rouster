Rouster
======

```rb
Rouster.is_a?('abstraction layer for controlling Vagrant virtual machines')
=> true
```

Rouster was conceived as the missing piece needed to functionally test Puppet manifests: while RSpec is nice (and _much_ faster), compiling a catalog and applying it are 2 distinct operations.

```rb
app = Rouster.new(:name => 'default' )
app.up()

p app.run('/sbin/service puppet once -t', 2)
# or p app.run_puppet('master', { :expected_exitcode => 2}), if you've required 'rouster/puppet'

app.destroy()
```

The first implementation of Rouster was in Perl, called [Salesforce::Vagrant](http://github.com/forcedotcom/SalesforceVagrant). Salesforce::Vagrant is functional, but new functionality may or may not be ported back.

## Requirements

* [Ruby](http://rubylang.org), version 2.0+ (best attempt made to support 1.8.7 and 1.9.3 as well)
* [Vagrant](http://vagrantup.com), version 1.0.5+
* Gems
  * json
  * log4r
  * net-scp
  * net-ssh

Note: Rouster should work exactly the same on Windows as it does on \*nix and OSX (minus rouster/deltas.rb functionality, at least currently),
but no real testing has been done to confirm this. Please file issues as appropriate.

### From-source installation (latest)

```sh
git clone https://github.com/chorankates/rouster.git
cd rouster
rake buildgem
gem install rouster-<version>.gem
```

### pre-built gem installation (stable)

[RubyGems](http://rubygems.org/gems/rouster)
[![Gem Version](https://badge.fury.io/rb/rouster.png)](http://badge.fury.io/rb/rouster)

```sh
gem install rouster
```

## Using Rouster

Rouster supports many of the vagrant faces:
* destroy()
* suspend()
* status()
* up()

All Rouster workers also support:
* get()
* put()
* rebuild()
* restart()
* run()

And depending on which pieces of rouster you 'require':

* rouster/deltas
  * get_groups()
  * get_packages()
  * get_ports()
  * get_services()
  * get_users()

* rouster/puppet
  * facter()
  * get_catalog()
  * get_puppet_errors()
  * get_puppet_notices()
  * parse_catalog()
  * remove_existing_certs()
  * run_puppet()

* rouster/testing
  * validate_file()
  * validate_group()
  * validate_package()
  * validate_service()
  * validate_user()

* rouster/tests
  * is_dir?()
  * is_executable?()
  * is_file?()
  * is_group?()
  * is_in_file?()
  * is_in_path?()
  * is_package?()
  * is_port_active?()
  * is_port_open?()
  * is_process_running?())
  * is_readable?()
  * is_service?()
  * is_service_running?()
  * is_user?()
  * is_user_in_group?()
  * is_writeable?()

These additional methods are added to the Rouster object via class extension.

### basic instantiation and usage

```rb
require 'rouster'

# the value for the 'name' attribute should be a name shown when you execute `vagrant status`
app = Rouster.new(:name => 'default')

# equivalent to `vagrant up app`
app.up()

# STD(OUT|ERR) of this is available in app.get_output()
app.run('cat /etc/hosts')
app.put('new-foo', '/tmp/foo')
app.get('/tmp/foo')

app.destroy()
```

### functional puppet test

```rb
require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestPuppetRun < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'default', :verbose => 4)
    @app = Rouster.new(:name => 'default')
  end

  def test_it

    workers = [@ppm, @app]

    workers.each do |w|
      # tear them down and build back up for clean run
      w.destroy()
      w.up()

      #res = w.run('puppet agent -t --environment development', 2)
      assert_raises_nothing do
        res = w.run_puppet('master', { :expected_exitcode => 2 })
      end
      assert_match(/Finished catalog/, res, "output contains 'Finished catalog'")
    end
  end

  def teardown
    @ppm.destroy()
    @app.destroy()
  end

end
```


## Base Methods

```rb
irb(main):003:0> (Rouster.new(:name => 'default').methods - Object.methods).sort
=> [:_run, :_vm, :check_key_permissions, :connect_ssh_tunnel, :deltas, :destroy, :dir, :exitcode, :facter, :facts, :file, :generate_unique_mac, :get, :get_catalog, :get_groups, :get_output, :get_packages, :get_ports, :get_puppet_errors, :get_puppet_notices, :get_services, :get_ssh_info, :get_users, :is_available_via_ssh?, :is_dir?, :is_executable?, :is_file?, :is_group?, :is_in_file?, :is_in_path?, :is_package?, :is_passthrough?, :is_port_active?, :is_port_open?, :is_process_running?, :is_readable?, :is_service?, :is_service_running?, :is_user?, :is_user_in_group?, :is_writeable?, :log, :os_type, :output, :parse_catalog, :parse_ls_string, :passthrough, :put, :rebuild, :remove_existing_certs, :restart, :run, :run_puppet, :sshkey, :status, :sudo, :suspend, :traverse_up, :up, :uses_sudo?, :vagrantfile, :verbosity]
```
