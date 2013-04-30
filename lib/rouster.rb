class Rouster

  attr_reader :name, :passthrough, :sshkey, :vagrantfile
  attr_accessor :verbosity

  def initialize (name = 'unknown', verbosity = 0, vagrantfile = nil, sshkey = nil, passthrough = false)
    @name        = name
    @passthrough = passthrough
    @sshkey      = sshkey
    @vagrantfile = vagrantfile.nil? ? sprintf('%s/Vagrantfile', Dir.pwd) : vagrantfile
    @vagrantdir  = File.dirname(@vagrantfile)
    @verbosity   = verbosity

    # no key is specified
    if @sshkey.nil?
      if @passthrough.nil?
        # ask Vagrant for the path to the key
      else
        raise Rouster::InternalError, 'must specify key when using a passthrough host'
      end

    end

    # confirm found/specified key exists
    unless File.exists?(@sshkey)
      raise Rouster::InternalError, "specified key [#{@sshkey}] does not exist"
    end

    unless File.exists?(@vagrantfile)
      raise Rouster::InternalError, "specified Vagrantfile [#{@vagrantfile}] does not exist"
    end


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
  def output(index = 0)
    # return index'th array of output in LIFO order
  end

end

# custom exceptions
class Rouster::InternalError < StandardError
  # thrown by most (if not all) Rouster methods
end

class Rouster::FileTransferError < StandardError
  # thrown by get() and put()
end

class Rouster::RemoteExecutionError < StandardError
  # thrown by run()
end

# TODO port this to an actual script
# for now, ~ caller() hack
if __FILE__ == $0

  app = Rouster.new(:name => 'app')
  ppm = Rouster.new(:name => 'ppm', :verbosity => 4, :vagrantfile => '../piab/Vagrantfile')

  # passthrough boxes do not need to specify a name
  lpt = Rouster.new(:passthrough => 'local', :verbosity => 4)
  rpt = Rouster.new(:passthrough => 'remote', :verbosity => 4, :sshkey => '~/.ssh/id_dsa')

  workers = [app, ppm, lpt]

  workers.each do |v|

    p '%s config: ' % v.name
    p 'passthrough: %s' % v.passthrough
    p 'sshkey:      %s' % v.sshkey
    p 'vagrantfile: %s' % v.vagrantfile

    v.up()

    p '%s status: %s' % v, v.status()
    p '%s available via ssh: %s' % v, v.available_via_ssh?()

    v.suspend()

    p '%s status: %s' % v, v.status()
    p '%s available via ssh: %s' % v, v.available_via_ssh?()

    v.up()

    p '%s available via ssh: %s' % v, v.available_via_ssh?()

    # put a file on the box and then bring it back
    v.put(__FILE__, '/tmp/foobar')
    v.get('/tmp/foobar', 'foobar_from_piab_host')

    # output should be the same
    p '%s uname -a via run:    %s' % v, v.run('uname -a')
    p '%s uname -a via output: %s' % v, v.output()

    # tear the box down
    v.destroy()

    p '%s status: %s' % v, v.status()
    p '%s available via ssh: %s' % v, v.available_via_ssh?()

  end

end
