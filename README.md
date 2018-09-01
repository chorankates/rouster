Rouster
======

[![build status](https://travis-ci.org/chorankates/rouster.svg)](https://travis-ci.org/chorankates/rouster) [![Gem Version](https://badge.fury.io/rb/rouster.svg)](https://rubygems.org/gems/rouster)

```rb
Rouster.is_a?('abstraction layer for controlling Vagrant virtual machines')
=> true
```

Rouster was conceived as the missing piece needed to functionally test Puppet manifests: while RSpec is nice (and _much_ faster), compiling a catalog and applying it are 2 distinct operations.

```rb
app = Rouster.new(:name => 'app' )
app.up()

p app.run('/sbin/service puppet once -t', 2)
# or p app.run_puppet('master', { :expected_exitcode => 2}), if you've required 'rouster/puppet'

app.destroy()
```

The first implementation of Rouster was in Perl, called [Salesforce::Vagrant](http://github.com/forcedotcom/SalesforceVagrant). Salesforce::Vagrant is functional, but new functionality may or may not be ported back.

## Requirements

* [Ruby](http://rubylang.org), version 2.1+
* [Vagrant](http://vagrantup.com), version 1.0.5+
* Gems
  * json
  * log4r
  * net-scp
  * net-ssh
  * fog (only if using AWS or OpenStack)

Note: Rouster should work exactly the same on Windows as it does on \*nix and OSX (minus rouster/deltas.rb functionality, at least currently),
but no real testing has been done to confirm this. Please file issues as appropriate.

### From-source local usage (latest)

```sh
git clone https://github.com/chorankates/rouster.git
cd rouster
bundle install # use :aws to pull in fog
...
irb(main):001:0> require './path_helper.rb'
=> true
irb(main):002:0> require 'rouster'
=> true
```

### From-source installation (latest)

```sh
git clone https://github.com/chorankates/rouster.git
cd rouster
rake buildgem
gem install rouster-<version>.gem
...
irb(main):001:0> require 'rouster'
=> true
```

### pre-built gem installation (stable)

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
app = Rouster.new(:name => 'app')

# equivalent to `vagrant up app`
app.up()

# STD(OUT|ERR) of this is available in app.get_output()
app.run('cat /etc/hosts')
app.put('new-foo', '/tmp/foo')
app.get('/tmp/foo')

app.destroy()
```

### advanced instantiation (passthroughs!)

detailed options in ```examples/passthrough.rb```, ```examples/aws.rb``` and ```examples/openstack.rb```

since Rouster only requires an SSH connection to control a machine, why stop at Vagrant?

```rb
require 'rouster'
require 'rouster/plugins/aws'
require 'rouster/plugins/openstack'

# control the machine rouster itself is running on
local = Rouster.new(:name => 'local', :passthrough => { :type => :local } }

# control a remote machine
remote = Rouster.new(
  :name => 'remote',
  :passthrough => {
    :type => :remote,
    :host => 'foo.bar.com',
    :user => 'keanu',
    :key  => '/path/to/private/key',
  }

  :sudo => true, # false by default, enabling requires that sshd is not enforcing 'requiretty'
)

# control a running EC2 instance
aws_already_running = Rouster.new(
  :name => 'cloudy',
  :passthrough => {
    :type     => :aws,
    :instance => 'your-instance-id',
    :keypair  => 'your-keypair-name',
  }
)

# start and control an EC2 instance
aws_start_me_up = Rouster.new(
  :name        => 'bgates',
  :passthrough => {
    :type            => :aws,
    :ami             => 'your-ami-id',
    :security_groups => 'your-security-groups',
    :key_id          => 'your-aws-key-id',     # defaults to ${AWS_ACCESS_KEY_ID}
    :secret_key      => 'your-aws-secret-key', # defaults to ${AWS_SECRET_ACCESS_KEY}
  }
)

# create a remote OpenStack instance
ostack = Rouster.new(
  :name      => 'ostack-testing',
  :passthrough => {
    :type                => :openstack,
    :openstack_auth_url  => 'http://hostname.domain.com:5000/v2.0/tokens',
    :openstack_username  => 'some_console_user',
    :openstack_tenant    => 'tenant_id',
    :user                => 'some_ssh_userid', 
    :keypair             => 'keypair_name',
    :image_ref           => 'c0340afb-577d-4db6-1234-aebdd6d1838f',
    :flavor_ref          => '547d9af5-096c-44a3-1234-7d23162556b8',
    :openstack_api_key   => 'some_api_key',
    :key                 => '/path/to/private/key.pem',
  },
  :sudo => true, # false by default, enabling requires that sshd is not enforcing 'requiretty'
)

# control a running OpenStack instance
openstack_already_running = Rouster.new(
  :name      => 'ostack-copy',
  :passthrough => {
    :type                => :openstack,
    :openstack_auth_url  => 'http://hostname.domain.com:5000/v2.0/tokens',
    :openstack_username  => 'some_console_user',
    :openstack_tenant    => 'tenant_id',
    :user                => 'ssh_user',
    :keypair             => 'keypair_name',
    :instance            => 'your-instance-id',
  },
)

```

### functional puppet test

```rb
require 'rouster'
require 'rouster/puppet'
require 'test/unit'

class TestPuppetRun < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new(:name => 'ppm', :verbose => 4)
    @app = Rouster.new(:name => 'app')
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
irb(main):001:0> require './path_helper.rb'
=> true
irb(main):002:0> require 'rouster'
=> true
irb(main):003:0> pp (Rouster.new(:name => 'app').methods - Object.methods).sort
=> [
[:_run,
 :cache,
 :cache_timeout,
 :check_key_permissions,
 :connect_ssh_tunnel,
 :deltas,
 :destroy,
 :dir,
 :dirs,
 :disconnect_ssh_tunnel,
 :exitcode,
 :facts,
 :facts=,
 :file,
 :files,
 :generate_unique_mac,
 :get,
 :get_crontab,
 :get_groups,
 :get_output,
 :get_packages,
 :get_ports,
 :get_services,
 :get_ssh_info,
 :get_users,
 :halt,
 :is_available_via_ssh?,
 :is_dir?,
 :is_executable?,
 :is_file?,
 :is_group?,
 :is_in_file?,
 :is_in_path?,
 :is_package?,
 :is_passthrough?,
 :is_port_active?,
 :is_port_open?,
 :is_process_running?,
 :is_readable?,
 :is_service?,
 :is_service_running?,
 :is_symlink?,
 :is_user?,
 :is_user_in_group?,
 :is_vagrant_running?,
 :is_writeable?,
 :logger,
 :os_type,
 :output,
 :package,
 :parse_ls_string,
 :passthrough,
 :put,
 :rebuild,
 :restart,
 :retries,
 :run,
 :sandbox_available?,
 :sandbox_commit,
 :sandbox_off,
 :sandbox_on,
 :sandbox_rollback,
 :sshkey,
 :status,
 :suspend,
 :traverse_up,
 :unittest,
 :up,
 :uses_sudo?,
 :vagrant,
 :vagrantbinary,
 :vagrantfile]
]
```

## AWS methods
```rb
irb(main):001:0> require './path_helper.rb'
=> true
irb(main):002:0> require 'rouster'
=> true
irb(main):003:0> require 'rouster/plugins/aws'
=> true
irb(main):004:0> pp (Rouster.new(:name => 'aws', :passthrough => { :type => :aws }).methods - Object.methods).sort
=> [
...
 :aws_bootstrap,
 :aws_connect,
 :aws_connect_to_elb,
 :aws_describe_instance,
 :aws_destroy,
 :aws_get_ami,
 :aws_get_hostname,
 :aws_get_instance,
 :aws_get_ip,
 :aws_get_metadata,
 :aws_get_url,
 :aws_get_userdata,
 :aws_status,
 :ec2,
 :elb,
 :elb_connect,
 :find_ssh_elb,
 :instance_data,
...
]
```

## Openstack methods

```rb
[
  :ostack_connect,
  :ostack_describe_instance,
  :ostack_destroy,
  :ostack_get_instance_id,
  :ostack_get_ip,
  :ostack_status,
  :ostack_up
]
```
