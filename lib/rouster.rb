require 'rubygems'
require 'log4r'
require 'json'

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/tests'

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

  attr_reader :deltas, :exitcode, :facts, :log, :name, :output, :passthrough, :ssh, :sshkey, :sudo, :vagrantfile, :verbosity, :_vm

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
    @ssh      = nil # will be hash containing connection information

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity # DEBUG (1) < INFO (2) < WARN < ERROR < FATAL (5)

    unless File.file?(@vagrantfile)
      raise InternalError.new(sprintf('specified Vagrantfile [%s] does not exist', @vagrantfile))
    end

    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise InternalError.new('must specify sshkey when using a passthrough host')
      else
        @sshkey = sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME'])
      end
    end

    ## shellout hackiness
    @_vm = nil

    # confirm found/specified key exists
    begin
      raise InternalError.new('ssh key not specified') if @sshkey.nil?
      raise InternalError.new('ssh key does not exist') unless File.file?(@sshkey)
      # TODO implement this method
      #@_vm.ssh.check_key_permissions(@sshkey)
    rescue => e
      raise InternalError.new("specified key [#{@sshkey}] has bad permissions. Vagrant exception: [#{e.message}]")
    end

    if opts.has_key?(:sshtunnel) and opts[:sshtunnel]
      #unless @_vm.state.to_s.eql?('running')
        @log.info(sprintf('upping machine[%s] in order to open SSH tunnel', @name))
        self.up()
      #end

      # could we call self.is_available_via_ssh? or does that need to happen outside initialize
      @log.debug('opening SSH tunnel..')
      #@_vm.channel.ready?()
    end

    # make sure the name is valid
    raise InternalError.new() if @name.nil?

    begin
      self.status()
    rescue Rouster::LocalExecutionError
      raise InternalError.new()
    end

    @log.debug('Rouster object successfully instantiated')

  end

  def inspect
    "name [#{@name}]:
      passthrough[#{@passthrough}],
      sshkey[#{@sshkey}],
      status[#{self.status()}]
      sudo[#{@sudo}],
      vagrantfile[#{@vagrantfile}],
      verbosity[#{@verbosity}]\n"
  end

  ## Vagrant methods
  def up
    @log.info('up()')
    self._run(sprintf('cd %s; vagrant up %s', File.dirname(@vagrantfile), @name))
  end

  def destroy
    @log.info('destroy()')
    self._run(sprintf('cd %s; vagrant destroy -f %s', File.dirname(@vagrantfile), @name))
  end

  def status
    @log.info('status()')
    self._run(sprintf('cd %s; vagrant status %s', File.dirname(@vagrantfile), @name))

    # else case here is handled by non-0 exit code
    if self.get_output().match(/^#{@name}\s*(.*)\s(.+)$/)
      # $1 = name, $2 = provider
      $1
    end

  end

  def suspend
    @log.info('suspend()')
    self._run(sprintf('cd %s; vagrant suspend %s', File.dirname(@vagrantfile), @name))
  end

  ## internal methods
  #private -- commented out so that unit tests can pass, should probably use the 'make all private methods public' method discussed in issue #28

  def run(command, expected_exitcode=[0])
    # runs a command inside the Vagrant VM
    output = nil
    expected_exitcode = [expected_exitcode] unless expected_exitcode.class.eql?(Array) # yuck

    @log.info(sprintf('vm running: [%s]', command))

    cmd    = sprintf('%s %s%s 2>&1', self.get_ssh_command(), self.uses_sudo? ? 'sudo ' : '', command)
    output = `#{cmd}`
    @exitcode = $?.to_i()
    self.output.push(output)

    # TODO fix the bug here
    unless expected_exitcode.member?(@exitcode)
      raise RemoteExecutionError.new("output[#{output}], exitcode[#{@exitcode}], expected[#{expected_exitcode}]")
    end

    @exitcode ||= 0
    output
  end

  def is_available_via_ssh?
    # functional test to see if Vagrant machine can be logged into via ssh
    begin
      self.run('echo foo')
    rescue
      return false
    end

    true
  end

  def get_ssh_command

    h = Hash.new()

    if @ssh.class.eql?(Hash)
      h = @ssh
    else
      res = self._run(sprintf('cd %s; vagrant ssh-config %s', File.dirname(@vagrantfile), @name))

      res.split("\n").each do |line|
        if line.match(/HostName (.*?)$/)
          h[:hostname] = $1
        elsif line.match(/User (\w*?)$/)
          h[:user] = $1
        elsif line.match(/Port (\d*?)$/)
          h[:ssh_port] = $1
        elsif line.match(/IdentityFile (.*?)$/)
          # TODO what to do if the user has specified @sshkey ?
          h[:identity_file] = $1
        end
      end

      @ssh = h
    end

    sprintf('ssh -p %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s %s@%s', h[:ssh_port], h[:identity_file], h[:user], h[:hostname])
  end

  def get_scp_command

    h = Hash.new()

    if @ssh.class.eql?(Hash)
      h = @ssh
    else
      res = self._run(sprintf('cd %s; vagrant ssh-config %s', File.dirname(@vagrantfile), @name))

      res.split("\n").each do |line|
        if line.match(/HostName (.*?)$/)
          h[:hostname] = $1
        elsif line.match(/User (\w*?)$/)
          h[:user] = $1
        elsif line.match(/Port (\d*?)$/)
          h[:ssh_port] = $1
        elsif line.match(/IdentityFile (.*?)$/)
          # TODO what to do if the user has specified @sshkey ?
          h[:identity_file] = $1
        end
      end

      @ssh = h

    end

    sprintf('scp -B -P %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o IdentitiesOnly=yes -i %s', h[:ssh_port], h[:identity_file])
  end

  def os_type(start_if_not_running=true)
    # if the machine isn't created, typically see 'Vagrant::Guest::Linux'
    # returns :RedHat, :Solaris or :Ubuntu

    if start_if_not_running and self.status.eql?('running').false?
      @log.debug('starting machine to determine OS type')
      self.up()
    end

    uname = self.run('uname -a')

    case uname
      when /Darwin/i
        :osx
      when /Sun|Solaris/i
        :solaris
      when /Ubuntu/i
        :ubuntu
      else
        if self.is_file?('/etc/redhat-release')
          :redhat
        else
          nil
        end
    end

  end

  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file
    @log.debug(sprintf('scp from VM[%s] to host[%s]', remote_file, local_file))

    raise SSHConnectionError.new(sprintf('unable to get[%s], SSH connection unavailable', remote_file)) unless self.is_available_via_ssh?

    begin
      self._run(sprintf('%s %s@%s:%s %s', self.get_scp_command, @ssh[:user], @ssh[:hostname], remote_file, local_file))
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
      self._run(sprintf('%s %s %s@%s:%s', self.get_scp_command, local_file, @ssh[:user], @ssh[:hostname], remote_file))
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
    self.destroy
    self.up
  end

  def restart(wait=nil)
    @log.debug('restart()')
    # restarts a Vagrant machine, wait time is same as rebuild()
    # how do we do this in a generic way? shutdown -rf works for Unix, but not Solaris

    if self.is_passthrough? and self.passthrough.eql?(local)
      @log.warn(sprintf('intercepted [restart] sent to a local passthrough, no op'))
      return nil
    end

    # MVP
    self.run('/sbin/shutdown -rf now')

    if wait
      inc = wait.to_i / 10
      0..wait.each do |e|
        @log.debug(sprintf('waiting for reboot: round[%s], step[%s], total[%s]', e, inc, wait))
        true if self.is_available_via_ssh?()
        sleep inc
      end

      false
    end

  end

  def _run(command)
    # shells out and executes a command locally on the system, different than run(), which operates in the VM
    # returns STDOUT|STDERR, raises Rouster::LocalExecutionError on non 0 exit code

    tmp_file = sprintf('/tmp/rouster.%s.%s', Time.now.to_i, $$)
    cmd      = sprintf('%s > %s 2> %s', command, tmp_file, tmp_file) # this is a holdover from Salesforce::Vagrant, can we use '2&>1' here?
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

  def get_output(index = 1)
    # return index'th array of output in LIFO order (recasts positive or negative as best as it can)
    index.is_a?(Fixnum) and index > 0 ? self.output[-index] : self.output[index]
  end

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
