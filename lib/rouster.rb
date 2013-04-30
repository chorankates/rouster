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
      if @passthrough.eql?(true)
        raise Rouster::InternalError, 'must specify key when using a passthrough host'
      else
        # ask Vagrant for the path to the key
      end

    end

    # confirm found/specified key exists
    if @sshkey.nil? or ! File.exists?(@sshkey)
      raise Rouster::InternalError, "specified key [#{@sshkey}] does not exist"
    end

    if ! File.exists?(@vagrantfile)
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
