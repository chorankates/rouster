require 'rubygems'

# TODO be smarter about this
#require '/Applications/Vagrant/embedded/gems/gems/vagrant-1.0.5/lib/vagrant'

# TODO combine/refactor the get_scp_command(), get_ssh_command() synergies

# need to install log4r before can do above
# -- looks like vagrant/cli will be one that we want -> env = Vagrant::Environment.new({}); env.cli(ARGV)
# -- and vagrant/ssh will be the other -> ssh = Vagrant::SSH.new(vm) <-- need to see if that is actually correct

class Rouster

  attr_reader :name, :output, :passthrough, :sshkey, :sudo, :vagrant, :vagrantdir, :vagrantfile
  attr_accessor :sshinfo, :verbosity

  # poor man logging values for now
  NOTICE = 0
  ERROR  = 1
  WARN   = 2
  INFO   = 3
  DEBUG  = 4


  def initialize (name = 'unknown', verbosity = 0, vagrantfile = nil, sshkey = nil, sudo = true, passthrough = false)
    @name        = name
    @output      = Array.new
    @passthrough = passthrough
    @sshkey      = sshkey
    @sudo        = (sudo.nil? or @passthrough.eql?(true)) ? false : true
    @vagrantfile = vagrantfile.nil? ? sprintf('%s/Vagrantfile', Dir.pwd) : vagrantfile
    @vagrantdir  = File.dirname(@vagrantfile)
    @verbosity   = verbosity

    # no key is specified
    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise Rouster::InternalError, 'must specify sshkey when using a passthrough host'
      else
        # TODO do this via the vagrant library
        # ask Vagrant for the path to the key
        begin
          res = self.run_vagrant("ssh-config #{self.name}")
        rescue Rouster::LocalExecutionError => e
          raise Rouster::InternalError, 'unable to query Vagrant for sshkey'
        end

        # TODO need to wrap this into the get_ssh_prefix / get_scp_prefix pattern so we aren't parsing it everywhere
        if res =~ /IdentityFile\s*(.*?)$/
          @sshkey = $1
        end

      end

    end

    # confirm found/specified key exists
    if @sshkey.nil? or ! File.exists?(@sshkey)
      raise Rouster::InternalError, "specified key [#{@sshkey}] does not exist"
    end

    unless File.exists?(@vagrantfile)
      raise Rouster::InternalError, "specified Vagrantfile [#{@vagrantfile}] does not exist"
    end

    # TODO need to confirm validity before we go on
    # in Salesforce::Vagrant we constantly checked whether an object was 'valid' and then again at its 'status' -- not doing that again


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
    cmd     = sprintf('%s -t %s%s', self.get_ssh_prefix(), self.uses_sudo? ? 'sudo ' : '', command)
    self._run(cmd)
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

    begin
      self.run('uname -a')
    rescue Rouster::SSHConnectionError
      false
    end

    true
  end

  def log(msg, level=NOTICE)
    #raise Rouster::NotImplementedError
    puts "#{level}: #{msg}\n"
  end

  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file

    res = self.status()

    raise Rouster::SSHConnectionError sprintf('unable to get [%s], box is in status [%s]', remote_file, res) unless res.eql?('running')

    cmd = sprintf(
      '%s %s@%s:%s %s',
      self.get_scp_prefix(),
      self.sshinfo[:user],
      self.sshinfo[:hostname],
      remote_file,
      local_file
    )

    begin
      # assuming this doesn't fail, does the return of this method get passed back up the stack?
      self._run(cmd)
    rescue Rouster::LocalExecutionError => e
      raise Rouster::SSHConnectionError sprintf('unable to get [%s], command [%s] returned [%s]', remote_file, cmd, self.get_output())
    end

  end

  def put(local_file, remote_file=nil)
    remote_file = remote_file.nil? ? File.basename(local_file) : remote_file

    res = self.status()
    raise Rouster::SSHConnectionError sprintf('unable to get [%s], box is in status [5s]', local_file, res) unless res.eql?('running')

    cmd = sprintf(
      '%s %s %s@%s:%s',
      self.get_scp_prefix(),
      local_file,
      self.sshinfo[:user],
      self.sshinfo[:hostname],
      remote_file
    )

    begin
      self._run(cmd)
    rescue Rouster::LocalExecutionError
      raise Rouster::SSHConnectionError sprintf('unable to get [%s], command [%s] returned [%s]', local_file, cmd, self.get_output())
    end

  end

  # there has _got_ to be a more rubyish way to do this
  def is_passthrough?
    self.passthrough.eql?(true)
  end

  def uses_sudo?
    # convenience method for the @sudo attribute
     self.sudo.eql?(true)
  end

  def rebuild()
    # destroys/reups a Vagrant machine

    self.run_vagrant('destroy')
    self.run_vagrant('up')

    # TODO decide what the return from this should be.. nothing? only throw exceptions when you need to?

  end

  def restart(wait = 120)
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris

    # MVP
    self.run('/sbin/shutdown -rf now')

    # TODO implement some 'darwin award' checks in case someone tries to reboot a local passthrough?

  end

  def _run(command)
    # shells out and executes a command locally on the system, different than run(), which operates in the VM
    # returns STDOUT|STDERR, raises Rouster::LocalExecutionError on non 0 exit code

    tmp_file = sprintf('/tmp/rouster.%s.%s', Time.now.to_i, $$)
    cmd      = sprintf('%s > %s 2> %s', command, tmp_file, tmp_file)
    res      = `#{cmd}` # what does this actually hold?

    output = File.read(tmp_file)
    File.delete(tmp_file) or raise Rouster::InternalError sprintf('unable to delete [%s]: %s', tmp_file, $!)

    unless $?.success?
      raise Rouster::LocalExecutionError sprintf('command [%s] exited with code [%s], output [%s]', cmd, $?.to_i(), output)
    end

    self.output.push(output)
    output
  end

  ## truly internal methods
  def get_ssh_prefix
    # TODO replace this with something Vagranty

    if self.sshinfo.nil?
      hash   = Hash.new
      output = self.run_vagrant("ssh-config #{self.name}")

      output.each_line do |line|
        if line =~ /HostName (.*?)$/
          hash[:hostname] = $1
        elsif line =~ /User (\w*?)$/
          hash[:user] = $1
        elsif line =~ /Port (\d*?)$/
          hash[:port] = $1
        elsif line =~ /IdentityFile (.*?)$/
          hash[:sshkey] = $1
        end
      end

      self.sshinfo = hash
    end

    sprintf(
      'ssh -p %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s@%s',
      self.sshinfo[:port],
      self.sshinfo[:sshkey],
      self.sshinfo[:user],
      self.sshinfo[:hostname]
    )
  end

  def get_scp_prefix

    if self.sshinfo.nil?
      hash   = Hash.new
      output = self.run_vagrant("ssh-config #{self.name}")

      output.each_line do |line|
        if line =~ /HostName (.*?)$/
          hash[:hostname] = $1
        elsif line =~ /User (\w*?)$/
          hash[:user] = $1
        elsif line =~ /Port (\d*?)$/
          hash[:port] = $1
        elsif line =~ /IdentityFile (.*?)$/
          hash[:sshkey] = $1
        end
      end

      self.sshinfo = hash
    end

    a = sprintf(
      'scp -B -P %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s',
      self.sshinfo[:port],
      self.sshinfo[:sshkey]
    )

    a
  end

  def get_output(index = 0)
    # return index'th array of output in LIFO order

    # TODO do this in a mathy way instead of a youre-going-to-run-out-of-memory-way
    reversed = self.output.reverse
    reversed[index]
  end

end

# custom exceptions -- what else do we want them to include/do?   should append the name of the box to the exception message
class Rouster::NotImplementedError < StandardError
  # could have sworn there was a built in 'not implemented' exception.. guess this'll do just as well
end

class Rouster::FileTransferError < StandardError
  # thrown by get() and put()
end

class Rouster::InternalError < StandardError
  # thrown by most (if not all) Rouster methods
end

class Rouster::LocalExecutionError < StandardError
  # thrown by _run()
end

class Rouster::RemoteExecutionError < StandardError
  # thrown by run()
end

class Rouster::SSHConnectionError < StandardError
  # thrown by available_via_ssh() -- and potentially _run()
end