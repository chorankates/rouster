class SalesforceVagrant

  attr_reader :name, :passthrough, :sshkey, :vagrantfile
  attr_accessor :verbosity

  def initialize (name = 'unknown', verbosity = 0, vagrantfile = nil, sshkey = nil, passthrough = false)
    # need a hook that if no sshkey is specified, we determine from `vagrant ssh-config` using the vagrantfile - if neither is specified, need to throw an exception
  end

  ## Vagrant methods
  def up

  end

  def destroy

  end

  def suspend

  end

  ## internal methods

  def available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
  end

  def rebuild(wait = 120)
    # destroys/reups a Vagrant machine, wait time is how long to wait for it to be available_via_ssh before throwing an exception
  end

  def restart(wait = 120)
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris
  end

  def run(command)

  end

  def status
    # return Vagrant box status
    # should we parse the output of `vagrant status <self.boxname>`? or use something internal to Vagrant?
  end

  ## truly internal methods
  def error(index = 0)
    # return index'th error in LIFO order
  end

  def error?
    # return true|false if last command|function executed had an error
  end

  def output(index = 0)
    # return index'th array of output in LIFO order
  end

end

# custom exceptions
class SalesforceVagrant::InternalError < StandardError
  # thrown by most (if not all) SalesforceVagrant methods
end

class SalesforceVagrant::FileTransferError < StandardError
  # thrown by get() and put()
end

class SalesforceVagrant::RemoteExecutionError < StandardError
  # thrown by run()
end


if __FILE__ == $0

  app = SalesforceVagrant.new(:name => 'app')
  ppm = SalesforceVagrant.new(:name => 'ppm', :verbosity => 4, :vagrantfile => '../piab/Vagrantfile')

  # passthrough boxes do not need to specify a name
  lpt = SalesforceVagrant.new(:passthrough => 'local', :verbosity => 4)
  rpt = SalesforceVagrant.new(:passthrough => 'remote', :verbosity => 4, :sshkey => '~/.ssh/id_dsa')

  workers = [app, ppm, lpt]

  workers.each do |v|

    v.up()

    p "%s errors: %s" % v, v.error()
    p "%s error?: %s" % v, v.error?()
    p "%s status: %s" % v, v.status()
    p "%s available via ssh: %s" % v, v.available_via_ssh?()

    v.suspend()

    p "%s errors: %s" % v, v.error()
    p "%s error?: %s" % v, v.error?()
    p "%s status: %s" % v, v.status()
    p "%s available via ssh: %s" % v, v.available_via_ssh?()

    v.up()

    p "%s available via ssh: %s" % v, v.available_via_ssh?()

    # put a file on the box and then bring it back
    v.put(__FILE__, '/tmp/foobar')
    v.get('/tmp/foobar', 'foobar_from_piab_host')

    # output should be the same
    p v.run('uname -a')
    p v.output()


    # tear the box down
    v.destroy()


  end

end
