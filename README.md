Rouster
======
```
Rouster.is_a?('abstraction layer for controlling Vagrant virtual machines')
=> true
```

It was conceived as the missing piece needed to functionally test Puppet manifests: while RSpec is nice (and _much_ faster), compiling a catalog and applying it are 2 distinct operations

```
app = Rouster.new(:name => 'app' )
app.up()
p app.run('/sbin/service puppet once -t', 2) # or p app.run_puppet(2), if you've required 'rouster/puppet'
app.destroy()
```

The first implementation was in Perl, called [Salesforce::Vagrant](http://github.com/forcedotcom/SalesforceVagrant). Salesforce::Vagrant is functional, but new functionality may or may not be ported back.

## Requirements

* [Vagrant](http://vagrantup.com), version 1.0.5+
* a usable Vagrantfile

Note: Vagrant itself requires VirtualBox or VMWare Fusion (1.0.3+)

Note: Rouster should work exactly the same on Windows as it does on \*nix and OSX (minus rouster/deltas.rb functionality, at least currently),
but no real testing has been done to confirm this. Please file issues as appropriate.

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
  * get_services()
  * get_users()

* rouster/puppet
  * facter()
  * get_catalog()
  * get_puppet_errors()
  * get_puppet_notices()
  * parse_catalog()
  * run_puppet()

* rouster/tests
  * is_dir?()
  * is_executable?()
  * is_file?()
  * is_group?()
  * is_in_file?()
  * is_in_path?()
  * is_package?()
  * is_readable?()
  * is_service?()
  * is_service_running?()
  * is_user?()
  * is_user_in_group?()
  * is_writeable?()

* rouster/testing
  * validate_file()
  * validate_group()
  * validate_package()
  * validate_service()
  * validate_user()

These additional methods are added to the Rouster via class extension.

### basic instantiation and usage

```
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

### functional puppet test

```
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
      res = w.run_puppet(2)
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
```
irb(main):003:0> (Rouster.new(:name => 'app').methods - Object.methods).sort
=> ["_env", "_run", "_vm", "_vm_config", "deltas", "destroy", "exitcode", "facts",
"get", "get_output", "is_available_via_ssh?", "is_passthrough?", "log", "output",
"passthrough", "put", "rebuild", "restart", "run", "status", "sudo", "suspend", "up",
"uses_sudo?", "vagrantfile", "verbosity"]
 ```
