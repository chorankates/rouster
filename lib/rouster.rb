require 'rubygems'
#require 'vagrant'

class Rouster

  attr_reader :name, :passthrough, :sshkey, :vagrant, :vagrantdir, :vagrantfile
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
        res = self.run_vagrant("ssh-config #{self.name}")

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

    # instantiate a Vagrant worker (or 2 or 3) here
    # need to run commands over ssh tunnel, sned files, get files
    #@vagrant =

  end

  ## Vagrant methods
  # currently implemented as `vagrant` shell outs
  def up
    self.run_vagrant("up #{self.name}")
  end

  def destroy
    self.run_vagrant("destroy -f #{self.name}")
  end

  def status
    res = self.run_vagrant("status #{self.name}")

    if res =~ /#{self.name}\s*(.*?)$/
      $1
    else
      raise Rouster::InternalError, 'unable to parse result from `vagrant status`: [%s]' % res
    end

  end

  def suspend
    self.run_vagrant("suspend #{self.name}")
  end

  ## internal methods
  def run(command)
    # runs a command inside the Vagrant VM
  end

  def run_vagrant(command)
    # not sure how we should actually call this
    #  - in Salesforce::Vagrant, we cd to the Vagrantfile directory
    #  - but here, we could potentially (probably?) use Vagrant itself to do the work

    # either way, abstracting it here
    if self.is_passthrough?
      # TODO figure out how to abstract logging properly
      # could be cool to use self.log.info(<msg>)
      self.log('vagrant(%s) is a no-op for passthrough workers' % command, INFO)
    else
      self._run(sprintf('cd %s; vagrant %s', self.vagrantdir, command))
    end

  end

  def available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
    # ssh and run uname or something similarly harmless and test exit code (? or use something internal to vagrant?)

    # refactor this later
    cmd_prefix = self.get_ssh_command()
    cmd = '%s -t uname -a' % cmd_prefix

    begin
      self._run(cmd)
    rescue Rouster::SSHConnectionError
      false
    end

    true
  end

  def log(msg, level=NOTICE)

  end

  # there has _got_ to be a more rubyish way to do this
  def is_passthrough?
    self.passthrough.eql?(false) ? false : true
  end

  def rebuild(wait = 120)
    # destroys/reups a Vagrant machine, wait time is how long to wait for it to be available_via_ssh before throwing an exception
  end

  def restart(wait = 120)
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris
  end

  def _run(command)
    # shells out and executes a command locally on the system, different than run(), which operates in the VM
    # returns STDOUT|STDERR, raises Rouster::LocalExecutionError on non 0 exit code

    cmd    = sprintf('%s', command)
    output = `#{cmd}`

    unless $?.success?
      raise Rouster::LocalExecutionError 'command [%s] exited with [%s]' % cmd, $?.to_i()
    end

    output

  end

  ## truly internal methods
  def get_ssh_command
    output = self.run_vagrant("ssh-config #{self.name}")
    hash   = Hash.new

    output.each_line do |line|
      if line =~ /HostName (.*?)$/
        hash[:hostname] = $1
      elsif line =~ /User (\w*?)$/
        hash[:user] = $1
      elsif line =~ /Port (\d+)$/
        hash[:port] = $1
      elsif line =~ /IdentityFile (.*?)$/
        hash[:sshkey] = $1
      end
    end

    sprintf(
        'ssh -p %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s@%s',
        hash[:port],
        hash[:sshkey],
        hash[:user],
        hash[:hostname]
    )
  end

  def output(index = 0)
    # return index'th array of output in LIFO order
  end

end

# custom exceptions -- what else do we want them to include/do?
class Rouster::InternalError < StandardError
  # thrown by most (if not all) Rouster methods
end

class Rouster::FileTransferError < StandardError
  # thrown by get() and put()
end

class Rouster::SSHConnectionError < StandardError
  # thrown by available_via_ssh() -- and potentially _run()
end

class Rouster::LocalExecutionError < StandardError
  # thrown by _run()
end

class Rouster::RemoteExecutionError < StandardError
  # thrown by run()
end
