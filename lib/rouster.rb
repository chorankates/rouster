require 'rubygems'

require 'json'

$LOAD_PATH << '/Applications/Vagrant/embedded/gems/gems/vagrant-1.0.5/lib/'
require 'vagrant'

class Rouster
  VERSION = 0.1

  # custom exceptions -- what else do we want them to include/do?
  #   - should append the name of the box to the exception message
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_reader :deltas, :_env, :exitcode, :log, :name, :output, :passthrough, :sudo, :_ssh, :sshinfo, :vagrantfile, :verbosity, :_vm, :_vm_config

  def initialize(opts = nil)
    # process hash keys passed
    @name        = opts[:name] # since we're constantly calling .to_sym on this, might want to just start there
    @passthrough = opts[:passthrough].nil? ? false : opts[:passthrough]
    @sshkey      = opts[:sshkey]
    @vagrantfile = opts[:vagrantfile].nil? ? traverse_up(Dir.pwd, 'Vagrantfile', 5) : opts[:vagrantfile]
    @verbosity   = opts[:verbosity].is_a?(Integer) ? opts[:verbosity] : 5

    if opts.has_key?(:sudo)
      @sudo = opts[:sudo]
    elsif @passthrough.eql?(true)
      @sudo = false
    else
      @sudo = true
    end

    @output      = Array.new
    @sshinfo     = Hash.new
    @deltas      = Hash.new # should probably rename this, but container for tests.rb/get_*
    @exitcode    = nil

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity # DEBUG (1) < INFO (2) < WARN < ERROR < FATAL (5)

    unless File.file?(@vagrantfile)
      raise InternalError.new("specified Vagrantfile [#{@vagrantfile}] does not exist") unless File.file?(@vagrantfile)
    end

    @log.debug('instantiating Vagrant::Environment')
    @_env = Vagrant::Environment.new({:vagrantfile_name => @vagrantfile})

    @log.debug('loading Vagrantfile configuration')
    @_config = @_env.load_config!

    raise InternalError.new(sprintf('specified VM name [%s] not found in specified Vagrantfile', @name)) unless @_config.for_vm(@name.to_sym)

    # need to set base MAC here, not sure why we have never had to specify this previously
    @_vm_config = @_config.for_vm(@name.to_sym)
    @_vm_config.vm.base_mac = 'b88d12044242' # causes a fatal error with VboxManage if colons are left in

    @log.debug('instantiating Vagrant::VM')
    @_vm = Vagrant::VM.new(@name, @_env, @_vm_config)

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

    config_keys = @_vm_config.keys
    self.sshinfo[:host] = config_keys[:ssh].host
    self.sshinfo[:port] = config_keys[:ssh].port
    self.sshinfo[:user] = config_keys[:ssh].username
    self.sshinfo[:key]  = @sshkey

  end

  def inspect
    "name [#{@name}]:
      created[#{@_vm.created?}],
      passthrough[#{@passthrough}],
      sshkey[#{@sshkey}],
      status[#{self.status()}]
      sudo[#{@sudo}],
      vagrantfile[#{@vagrantfile}],
      verbosity[#{verbosity}],
      Vagrant Environment object[#{@_env.class}],
      Vagrant Configuration object[#{@_config.class}],
      Vagrant VM object[#{@_vm.class}]\n"
  end

  ## Vagrant methods
  def up
    @log.info('up()')

    if @_vm.created?
      self._run(sprintf('cd %s; vagrant up %s', File.dirname(@vagrantfile), @name))
    else
      @_vm.up
    end

    ## if the VM hasn't been created yet, we don't know the port
    @_config.for_vm(@name.to_sym).keys[:vm].forwarded_ports.each do |f|
      if f[:name].eql?('ssh')
        self.sshinfo[:port] = f[:hostport]
      end
    end

  end

  def destroy
    @log.info('destroy()')
    @_vm.destroy
  end

  def status
    @_vm.state.to_s
  end

  def suspend
    @log.info('suspend()')
    @_vm.suspend
  end

  ## internal methods
  def run(command)
    # runs a command inside the Vagrant VM
    output = nil

    @log.info(sprintf('vm running: [%s]', command))

    begin
      # TODO use a lambda here instead
      if self.uses_sudo?
        @_vm.channel.sudo(command) do |type,data|
          output ||= ""
          output += data
        end
      else
        @_vm.channel.execute(command) do |type,data|
          output ||= "" # don't like this, but borrowed from Vagrant, so feel less bad about it
          output += data
        end
      end
    rescue Vagrant::Errors::VagrantError => e
      # non-0 exit code, this is fatal for Vagrant, but not for us
      output        = e.message
      @exitcode = 1 # TODO get the actual exit code
      raise RemoteExecutionError.new("output[#{output}], exitcode[#{@exitcode}]")
    end

    @exitcode ||= 0
    self.output.push(output)
    output
  end

  def available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
    @_vm.channel.ready?()
  end

  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file

    # TODO should we switch this over to self.created?
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

  def restart()
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris
    #   we can ask Vagrant what kind of machine this is, but how far down this hole do we really want to go?

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

    @log.info(sprintf('host running: [%s]', cmd))

    output = File.read(tmp_file)
    File.delete(tmp_file) or raise InternalError.new(sprintf('unable to delete [%s]: %s', tmp_file, $!))

    unless $?.success?
      raise LocalExecutionError.new(sprintf('command [%s] exited with code [%s], output [%s]', cmd, $?.to_i(), output))
    end

    self.output.push(output)
    @exitcode = $?.to_i()
    output
  end

  ## truly internal methods
  def traverse_up(startdir=Dir.pwd, filename=nil, levels=10)

    raise InternalError.new('must specify a filename') if filename.nil?

    dirs  = startdir.split('/')
    count = 0

    while count < levels and ! dirs.nil?

      potential = sprintf('%s/Vagrantfile', dirs.join('/'))

      if File.file?(potential)
        return potential
      end

      dirs.pop()
      count += 1
    end
  end

  def get_output(index = 0)
    # return index'th array of output in LIFO order

    # TODO do this in a mathy way instead of a youre-going-to-run-out-of-memory-way
    reversed = self.output.reverse
    reversed[index]
  end

end

