require 'rubygems'

# TODO be smarter about this
$LOAD_PATH << '/Applications/Vagrant/embedded/gems/gems/vagrant-1.0.5/lib/'
require 'vagrant'

# TODO combine/refactor the get_scp_command(), get_ssh_command() synergies

class Rouster
  VERSION = 0.1

  # custom exceptions -- what else do we want them to include/do?
  #   - should append the name of the box to the exception message
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_reader :_env, :exitcode, :name, :output, :passthrough, :sudo, :_ssh, :sshinfo, :vagrantfile, :verbosity, :_vm, :_vm_config

  def initialize(opts = nil)
    # process hash keys passed
    @name        = opts[:name] # since we're constantly calling .to_sym on this, might want to just start there
    @passthrough = opts.has_key?(:passthrough) ? false : opts[:passthrough]
    @sshkey      = opts[:sshkey]
    @sudo        = (opts.has_key?(:sudo) or @passthrough.eql?(true)) ? false : true
    @vagrantfile = vagrantfile.nil? ? sprintf('%s/Vagrantfile', Dir.pwd) : vagrantfile
    @verbosity   = (opts.has_key?(:verbosity) and opts[:verbosity].is_a?(Integer)) ? opts[:verbosity] : 0

    @output      = Array.new

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new('rouster')
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity # all, fatal, error, warn, info, debug, off

    @log.debug('instantiating Vagrant::Environment')
    @_env = Vagrant::Environment.new({:vagrantfile_name => @vagrantfile})
    # ["action_registry", "action_runner", "boxes", "boxes_path", "cli", "config",
    # "copy_insecure_private_key", "cwd", "default_private_key_path", "dotfile_path",
    # "find_vagrantfile", "gems_path", "global_data", "home_path", "host", "load!",
    # "load_config!", "load_plugins", "load_vms!", "loaded?", "local_data", "lock",
    # "lock_path", "multivm?", "primary_vm", "reload!", "root_path", "setup_home_path",
    # "tmp_path", "ui", "vagrantfile_name", "vms", "vms_ordered"]

    @log.debug('loading Vagrantfile configuration')
    @_config = @_env.load_config!
    # ["for_vm", "global", "vms"]

    raise InternalError.new(sprintf('specified VM name [%s] not found in specified Vagrantfile', @name)) unless @_config.for_vm(@name.to_sym)

    # need to set base MAC here, not sure why we have never had to specify this previously
    @_vm_config = @_config.for_vm(@name.to_sym)
    @_vm_config.vm.base_mac = '0a:00:27:00:42:42'

    @log.debug('instantiating Vagrant::VM')
    @_vm = Vagrant::VM.new(@name, @_env, @_vm_config)
    # ["box", "channel", "config", "created?", "destroy", "driver", "env",
    # "guest", "halt", "load_guest!", "package", "provision", "reload",
    # "reload!", "resume", "run_action", "ssh", "start", "state", "suspend", "ui",
    # "up", "uuid", "uuid=", "vm"]

    # no key is specified
    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise InternalError.new('must specify sshkey when using a passthrough host')
      else
        # ask Vagrant where the key is
        @sshkey = @_env.default_private_key_path
      end
    end

    # confirm found/specified key exists
    if @sshkey.nil? or @_vm.ssh.check_key_permissions(@sshkey)
      raise InternalError.new("specified key [#{@sshkey}] does not exist/has bad permissions")
    end

    unless File.exists?(@vagrantfile)
      raise InternalError.new("specified Vagrantfile [#{@vagrantfile}] does not exist")
    end

    config_keys = @_vm_config.keys
    self.sshinfo[:host] = config_keys[:ssh].host
    self.sshinfo[:port] = config_keys[:ssh].port
    self.sshinfo[:user] = config_keys[:ssh].username
    self.sshinfo[:key]  = @sshkey

  end

  def inspect
    "name [#{@name}]:
      passthrough[#{@passthrough}],
      sshkey[#{@sshkey}],
      sudo[#{@sudo}],
      vagrantfile[#{@vagrantfile}],
      verbosity[#{verbosity}],
      Vagrant Environment object[#{@_env.class}],
      Vagrant Configuration object[#{@_config.class}],
      Vagrant VM object[#{@_vm.class}]\n"
  end

  ## Vagrant methods
  # currently implemented as `vagrant` shell outs
  def up
    @_vm.up
  end

  def destroy
    @_vm.destroy
  end

  def status
    @_vm.state.to_s
  end

  def suspend
    @_vm.suspend
  end

  ## internal methods
  def run(command)
    # runs a command inside the Vagrant VM

    # TODO finish the conversion over to @_vm.ssh
    @log.info(sprintf('running [%s]', command))

    cmd = sprintf(
        'ssh -p %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s@%s -t -t %s%s',
        self.sshinfo[:port],
        self.sshinfo[:sshkey],
        self.sshinfo[:user],
        self.sshinfo[:hostname],
        self.uses_sudo? ? 'sudo ' : '',
        command
    )
    self._run(cmd)
    #@_vm.ssh.execute(cmd)
  end

  def run_vagrant(command)
    # not sure how we should actually call this
    #  - in Salesforce::Vagrant, we cd to the Vagrantfile directory
    #  - but here, we could potentially (probably?) use Vagrant itself to do the work

    # either way, abstracting it here
    if self.is_passthrough?
      # TODO figure out how to abstract logging properly
      # could be cool to use self.log.info(<msg>)
      @log.info('vagrant(%s) is a no-op for passthrough workers' % command)
    else
      self._run(sprintf('cd %s; vagrant %s', self.vagrantdir, command))
    end

  end

  def available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh

    # TODO use @_vm.ssh to test this

    begin
      self.run('uname -a')
    rescue Rouster::SSHConnectionError
      false
    end

    true
  end

  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file

    res = self.status()

    raise SSHConnectionError.new(sprintf('unable to get [%s], box is in status [%s]', remote_file, res)) unless res.eql?('running')

    cmd = sprintf(
      'scp -B -P %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s@%s:%s %s',
      self.sshinfo[:port],
      self.sshinfo[:key],
      self.sshinfo[:user],
      self.sshinfo[:hostname],
      remote_file,
      local_file
    )

    begin
      # assuming this doesn't fail, does the return of this method get passed back up the stack?
      self._run(cmd)
    rescue Rouster::LocalExecutionError => e
      raise SSHConnectionError.new(sprintf('unable to get [%s], command [%s] returned [%s]', remote_file, cmd, self.get_output()))
    end

  end

  def put(local_file, remote_file=nil)
    remote_file = remote_file.nil? ? File.basename(local_file) : remote_file

    res = self.status()
    raise SSHConnectionError.new(sprintf('unable to get [%s], box is in status [5s]', local_file, res)) unless res.eql?('running')

    cmd = sprintf(
      'scp -B -P %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s %s@%s:%s',
      self.sshinfo[:port],
      self.sshinfo[:key],
      local_file,
      self.sshinfo[:user],
      self.sshinfo[:hostname],
      remote_file
    )

    begin
      self._run(cmd)
    rescue Rouster::LocalExecutionError
      raise SSHConnectionError.new(sprintf('unable to get [%s], command [%s] returned [%s]', local_file, cmd, self.get_output()))
    end

  end

  def is_dir?(dir)
    # TODO implement this
    raise NotImplementedError.new()
  end

  def is_file?(file)
    # TODO implement this
    raise NotImplementedError.new()
  end

  def is_in_file?(file, regex, scp=0)
    # TODO implement this
    raise NotImplementedError.new()
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
    @_vm.destroy
    @_vm.up
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

    @log.debug(sprintf('running: [%s]', cmd)) # should this be an 'info'?

    output = File.read(tmp_file)
    File.delete(tmp_file) or raise InternalError.new(sprintf('unable to delete [%s]: %s', tmp_file, $!))

    unless $?.success?
      raise LocalExecutionError.new(sprintf('command [%s] exited with code [%s], output [%s]', cmd, $?.to_i(), output))
    end

    self.output.push(output)
    self.exitcode = $?.to_i()
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


  def get_output(index = 0)
    # return index'th array of output in LIFO order

    # TODO do this in a mathy way instead of a youre-going-to-run-out-of-memory-way
    reversed = self.output.reverse
    reversed[index]
  end

end

