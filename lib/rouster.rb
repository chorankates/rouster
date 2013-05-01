class Rouster

  attr_reader :name, :passthrough, :sshkey, :vagrantdir, :vagrantfile
  attr_accessor :verbosity

  def initialize (name = 'unknown', verbosity = 0, vagrantfile = nil, sshkey = nil, passthrough = false)
    @name        = name
    @passthrough = passthrough
    @sshkey      = sshkey
    @vagrantfile = vagrantfile.nil? ? sprintf('%s/Vagrantfile', Dir.pwd) : vagrantfile # doing it here so the instantiation line isn't too long
    @vagrantdir  = File.dirname(@vagrantfile)
    @verbosity   = verbosity

    # no key is specified
    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise Rouster::InternalError, 'must specify key when using a passthrough host'
      else
        # TODO do this via the vagrant library
        # ask Vagrant for the path to the key
        res = self.vagrant("ssh-config #{self.name}")

        @sshkey = $1 if res.grep(/IdentityFile\s(.*)$/)
      end

    end

    # confirm found/specified key exists
    if @sshkey.nil? or ! File.exists?(@sshkey)
      raise Rouster::InternalError, "specified key [#{@sshkey}] does not exist"
    end

    unless File.exists?(@vagrantfile)
      raise Rouster::InternalError, "specified Vagrantfile [#{@vagrantfile}] does not exist"
    end


  end

  ## Vagrant methods
  # currently implemented as `vagrant` shell outs
  def up
    self.vagrant("up #{self.name}")
  end

  def destroy
    self.vagrant("destroy -f #{self.name}")
  end

  def status
    self.vagrant("status #{self.name}")
  end

  def suspend
    self.vagrant("suspend #{self.name}")
  end

  ## internal methods
  def vagrant(command)
    # not sure how we should actually call this
    #  - in Salesforce::Vagrant, we cd to the Vagrantfile directory
    #  - but here, we could potentially (probably?) use Vagrant itself to do the work

    # either way, abstracting it here
    if self.is_passthrough?
      # TODO figure out how to abstract logging properly
      # could be cool to use self.log.info(<msg>)
      self.log('vagrant(%s) is a no-op for passthrough workers' % command, INFO)
    else
      self.run(sprintf('cd %s; vagrant %s', self.vagrantdir, command))
    end

  end

  def available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
    # ssh and run uname or something similarly harmless
  end

  def log(msg, level=NOTICE)

  end

  # there has _got_ to be a more rubyish way to do this
  def is_passthrough?
    self.passthrough eq false ? false : true
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
