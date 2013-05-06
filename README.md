Rouster
======
```
Rouster.is_a?('abstraction layer for interacting with Vagrant managed virtual machines')
=> true
```

It was conceived as the functional test answer to RSpec when Salesforce began rolling out [Puppet](http://www.puppetlabs.com), as many examples and comments will attest, but it can be used for much more.

```
app = Rouster.new({:name => 'app' })
app.up()
p app.run('/sbin/service puppet once -t')
app.destroy()
```

The first implementation was in Perl, called [Salesforce::Vagrant](http://github.com/forcedotcom/SalesforceVagrant). Salesforce::Vagrant is functional, but new functionality may or may not be ported back.

## Requirements

* [Vagrant](http://vagrantup.com), version 1.0.5+
* a usable Vagrantfile

Note: Vagrant itself requires VirtualBox or VMWare Fusion (1.0.3+)

Note: Rouster should work exactly the same on Windows as it does on \*nix and OSX, but no real testing has been done to confirm this. Please file issues as appropriate.

## Using Rouster

Rouster supports many of the vagrant faces:
* destroy()
* suspend()
* status()
* up()

### basic instantiation and usage

```
require 'rouster'

# the value for the 'name' attribute should be a name shown when you execute `vagrant status`
app = Rouster.new({:name => 'app' })

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
require 'test/unit'

class TestPuppetRun < Test::Unit::TestCase

  def setup
    @ppm = Rouster.new({:name => 'ppm', :verbose => 4})
    @app = Rouster.new({:name => 'app'})
  end

  def test_it

    workers = [@ppm, @app]

    workers.each do |w|
      # tear them down and build back up for clean run
      w.destroy()
      w.up()

      res = nil

      begin
        res = w.run('puppet agent -t --environment development')
      rescue Rouster::RemoteExecutionError
        # puppet gives a 2 exit code if a resource changes, need to catch the exception
        unless w.exitcode.eql?(2)
          raise Rouster::RemoteExecutionError.new("puppet run returned exitcode[#{w.exitcode}] and output[#{w.get_output()}]")
        end

        res = w.get_output()

        assert_equal(0 or 2, w.exitcode, "exit code [#{w.exitcode}] considered success")
        assert_match(/Finished catalog/, res, "output contains 'Finished catalog'")

      end
    end
  end

  def teardown
    @ppm.destroy()
    @app.destroy()
  end

end
```
