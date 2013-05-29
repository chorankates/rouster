require 'rubygems'
require 'json'

$LOAD_PATH << '/Applications/Vagrant/embedded/gems/gems/vagrant-1.0.5/lib/'
require 'vagrant'

require 'rouster/vagrant'

class Rouster
  VERSION = 0.2

  #TODO
  # set VirtualBox VM name to @name

  # custom exceptions -- what else do we want them to include/do?
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_reader :deltas, :_env, :exitcode, :facts, :log, :name, :output, :passthrough, :sshkey, :sudo, :vagrantfile, :verbosity, :_vm, :_vm_config

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

    @output   = Array.new
    @deltas   = Hash.new # should probably rename this, but need container for deltas.rb/get_*
    @facts    = Hash.new()
    @exitcode = nil

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity # DEBUG (1) < INFO (2) < WARN < ERROR < FATAL (5)

    unless File.file?(@vagrantfile)
      raise InternalError.new(sprintf('specified Vagrantfile [%s] does not exist', @vagrantfile))
    end

    @log.debug('instantiating Vagrant::Environment')
    @_env = Vagrant::Environment.new({:vagrantfile_name => @vagrantfile})

    @log.debug('loading Vagrantfile configuration')
    @_config = @_env.load_config!

    unless @name and @_config.for_vm(@name.to_sym)
      raise InternalError.new(sprintf('specified VM name [%s] not found in specified Vagrantfile', @name))
    end

    @_vm_config = @_config.for_vm(@name.to_sym)
    @_vm_config.vm.base_mac = generate_unique_mac()

    @log.debug('instantiating Vagrant::VM')
    @_vm = Vagrant::VM.new(@name, @_env, @_vm_config)

    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise InternalError.new('must specify sshkey when using a passthrough host')
      else
        # ask Vagrant where the key is
        @sshkey = @_env.default_private_key_path
      end
    end

    # confirm found/specified key exists
    begin
      raise InternalError.new('ssh key not specified') if @sshkey.nil?
      raise InternalError.new('ssh key does not exist') unless File.file?(@sshkey)
      @_vm.ssh.check_key_permissions(@sshkey)
    rescue Errors::SSHKeyBadPermissions
      raise InternalError.new("specified key [#{@sshkey}] has bad permissions")
    end

    if opts.has_key?(:sshtunnel) and opts[:sshtunnel]
      unless @_vm.state.to_s.eql?('running')
        @log.info(sprintf('upping machine[%s] in order to open SSH tunnel', @name))
        self.up()
      end

      # could we call self.is_available_via_ssh? or does that need to happen outside initialize
      @log.debug('opening SSH tunnel..')
      @_vm.channel.ready?()
    end

    @log.debug('Rouster object successfully instantiated')

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
    @_vm.channel.destroy_ssh_connection()

    # TODO need to dig deeper into this one -- issue #21
    if @_vm.created?
      self._run(sprintf('cd %s; vagrant up %s', File.dirname(@vagrantfile), @name))
    else
      @_vm.up
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
  def run(command, expected_exitcode=[0])
    # runs a command inside the Vagrant VM
    output = nil
    expected_exitcode = [expected_exitcode] unless expected_exitcode.class.eql?(Array) # yuck

    @log.info(sprintf('vm running: [%s]', command))

    # TODO use a lambda here instead
    if self.uses_sudo?
      @exitcode = @_vm.channel.sudo(command, { :error_check => false } ) do |type,data|
        output ||= ""
        output += data
      end
    else
      @exitcode = @_vm.channel.execute(command, { :error_check => false } ) do |type,data|
        output ||= "" # don't like this, but borrowed from Vagrant, so feel less bad about it
        output += data
      end
    end

    self.output.push(output)

    unless expected_exitcode.member?(@exitcode)
      raise RemoteExecutionError.new("output[#{output}], exitcode[#{@exitcode}], expected[#{expected_exitcode}]")
    end

    @exitcode ||= 0
    output
  end

  def is_available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
    @_vm.channel.ready?()
  end

  def os_type(start_if_not_running=true)
    # if the machine isn't created, typically see 'Vagrant::Guest::Linux'
    # returns :RedHat, :Solaris or :Ubuntu

    if start_if_not_running and self.status.eql?('running').false?
      @log.debug('starting machine to determine OS type')
      self.up()
    end

    if self.is_passthrough?
      uname = self.run('uname -a')

      case uname
        when /Darwin/i
          :osx
        when /Sun|Solaris/i
          :solaris
        when /Ubuntu/i
          :ubuntu
        else
          if self.is_file?('/etc/redhat/release')
            :redhat
          else
            nil
          end
      end
    else
      self._vm.guest.distro_dispatch()
    end

  end

  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file
    @log.debug(sprintf('scp from VM[%s] to host[%s]', remote_file, local_file))

    raise SSHConnectionError.new(sprintf('unable to get[%s], SSH connection unavailable', remote_file)) unless self.is_available_via_ssh?

    begin
      @_vm.channel.download(remote_file, local_file)
    rescue => e
      raise FileTransferError.new(sprintf('unable to get[%s], exception[%s]', remote_file, e.message()))
    end

  end

  def put(local_file, remote_file=nil)
    remote_file = remote_file.nil? ? File.basename(local_file) : remote_file
    @log.debug(sprintf('scp from host[%s] to VM[%s]', local_file, remote_file))

    raise FileTransferError.new(sprintf('unable to put[%s], local file does not exist', local_file)) unless File.file?(local_file)
    raise SSHConnectionError.new(sprintf('unable to put[%s], SSH connection unavailable', remote_file)) unless self.is_available_via_ssh?

    begin
      @_vm.channel.upload(local_file, remote_file)
    rescue => e
      raise FileTransferError.new(sprintf('unable to put[%s], exception[%s]', local_file, e.message()))
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

  def rebuild
    # destroys/reups a Vagrant machine
    @log.debug('rebuild()')
    @_vm.destroy
    @_vm.up
  end

  def restart
    @log.debug('restart()')
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris
    #   we can ask Vagrant what kind of machine this is, but how far down this hole do we really want to go?

    if self.is_passthrough? and self.passthrough.eql?(local)
      @log.warn(sprintf('intercepted [restart] sent to a local passthrough, no op'))
      return nil
    end

    # MVP
    self.run('/sbin/shutdown -rf now')

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

  # truly internal methods
  def get_output(index = 1)
    # return index'th array of output in LIFO order (recasts positive or negative as best as it can)
    index.is_a?(Fixnum) and index > 0 ? self.output[-index] : self.output[index]
  end

  private

  def generate_unique_mac
    # ht http://www.commandlinefu.com/commands/view/7242/generate-random-valid-mac-addresses
    #(1..6).map{"%0.2X" % rand(256)}.join('').downcase # causes a fatal error with VboxManage if colons are left in
    sprintf('b88d12%s', (1..3).map{"%0.2X" % rand(256)}.join('').downcase)
  end

  def traverse_up(startdir=Dir.pwd, filename=nil, levels=10)
    raise InternalError.new('must specify a filename') if filename.nil?

    @log.debug(sprintf('traverse_up() looking for [%s] in [%s], up to [%s] levels', filename, startdir, levels)) unless @log.nil?

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


end

# convenience truthiness methods
class Object
  def false?
    self.eql?(false)
  end

  def true?
    self.eql?(true)
  end
end
