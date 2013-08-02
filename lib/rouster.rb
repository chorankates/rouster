require 'rubygems'
require 'log4r'
require 'json'
require 'net/scp'
require 'net/ssh'

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/tests'

# see README for general information
class Rouster
  VERSION = 0.3

  #TODO
  # set VirtualBox VM name to @name
  # add caching to status()/is_available_via_ssh?() - for perf if you have stable environment/not edge testing

  # custom exceptions -- what else do we want them to include/do?
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_reader :deltas, :exitcode, :facts, :log, :name, :output, :passthrough, :sshkey, :sudo, :vagrantfile, :verbosity, :_vm

  def initialize(opts = nil)
    # process hash keys passed
    @name        = opts[:name]
    @passthrough = opts[:passthrough].nil? ? false : opts[:passthrough]
    @sshkey      = opts[:sshkey]
    @sshtunnel   = opts[:sshtunnel].nil? ? true : opts[:sshtunnel]
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
    @ssh_info = nil # will be hash containing connection information

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity # DEBUG (1) < INFO (2) < WARN < ERROR < FATAL (5)

    @log.debug('Vagrantfile and VM name validation..')
    unless File.file?(@vagrantfile)
      raise InternalError.new(sprintf('specified Vagrantfile [%s] does not exist', @vagrantfile))
    end

    raise InternalError.new() if @name.nil?

    begin
      self.status()
    rescue Rouster::LocalExecutionError
      raise InternalError.new()
    end

    @log.debug('SSH key discovery and viability tests..')
    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise InternalError.new('must specify sshkey when using a passthrough host')
      else
        @sshkey = sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME'])
      end
    end

    begin
      raise InternalError.new('ssh key not specified') if @sshkey.nil?
      raise InternalError.new('ssh key does not exist') unless File.file?(@sshkey)
      # TODO implement this method
      #@_vm.ssh.check_key_permissions(@sshkey)
    rescue => e
      raise InternalError.new("specified key [#{@sshkey}] has bad permissions. Vagrant exception: [#{e.message}]")
    end

    if @sshtunnel
      unless self.status.eql?('running')
        @log.info(sprintf('upping machine[%s] in order to open SSH tunnel', @name))
        self.up()
      end

      self.connect_ssh_tunnel()
    end

    @log.info('Rouster object successfully instantiated')
  end


  ##
  # inspect - overloaded method to return useful information about Rouster objects
  def inspect
    "name [#{@name}]:
      is_available_via_ssh?[#{self.is_available_via_ssh?}],
      passthrough[#{@passthrough}],
      sshkey[#{@sshkey}],
      status[#{self.status()}],
      sudo[#{@sudo}],
      vagrantfile[#{@vagrantfile}],
      verbosity[#{@verbosity}]\n"
  end

  ## Vagrant methods

  ##
  # up - shells out and runs 'vagrant up' from the Vagrantfile path
  # if :sshtunnel is passed to the object during instantiation, the tunnel is created here as well
  def up
    @log.info('up()')
    self._run(sprintf('cd %s; vagrant up %s', File.dirname(@vagrantfile), @name))

    @ssh_info = nil # in case the ssh-info has changed
    self.connect_ssh_tunnel() if @sshtunnel
  end

  ##
  # destroy - shells out and runs 'vagrant destroy <name>' from the Vagrantfile path
  def destroy
    @log.info('destroy()')
    self._run(sprintf('cd %s; vagrant destroy -f %s', File.dirname(@vagrantfile), @name))
  end

  ##
  # status - shells out and runs 'vagrant status <name>' from the Vagrantfile path
  # parses the status and provider out of output, but only status is returned
  def status
    @log.info('status()')
    self._run(sprintf('cd %s; vagrant status %s', File.dirname(@vagrantfile), @name))

    # else case here is handled by non-0 exit code
    if self.get_output().match(/^#{@name}\s*(.*\s?\w+)\s(.+)$/)
      # $1 = name, $2 = provider
      $1
    end

  end

  ##
  # suspend - shells out and runs 'vagrant suspend <name>' from the Vagrantfile path
  def suspend
    @log.info('suspend()')
    self._run(sprintf('cd %s; vagrant suspend %s', File.dirname(@vagrantfile), @name))
  end

  ## internal methods
  #private -- commented out so that unit tests can pass, should probably use the 'make all private methods public' method discussed in issue #28

  ##
  # run - runs a command inside the Vagrant VM
  #
  # returns output (STDOUT and STDERR) from command run, sets @exitcode
  # currently determines exitcode by tacking a 'echo $?' onto the command being run, which is then parsed out before returning
  #
  # parameters:
  # * <command> = the command to run (sudo will be prepended if specified in object instantiation)
  # * [expected_exitcode] = allows for non-0 exit codes to be returned without requiring exception handling
  def run(command, expected_exitcode=[0])
    output = nil
    expected_exitcode = [expected_exitcode] unless expected_exitcode.class.eql?(Array) # yuck, but 2.0 no longer coerces strings into single element arrays

    cmd = sprintf('%s%s; echo ec[$?]', self.uses_sudo? ? 'sudo ' : '', command)
    @log.info(sprintf('vm running: [%s]', cmd))

    output = @ssh.exec!(cmd)
    if output.match(/ec\[(\d+)\]/)
      @exitcode = $1.to_i
      output.gsub!(/ec\[(\d+)\]\n/, '')
    else
      @exitcode = 1
    end

    self.output.push(output)

    unless expected_exitcode.member?(@exitcode)
      raise RemoteExecutionError.new("output[#{output}], exitcode[#{@exitcode}], expected[#{expected_exitcode}]")
    end

    @exitcode ||= 0
    output
  end

  ##
  # is_available_via_ssh?
  #
  # returns true or false after:
  # * attempting to establish SSH tunnel if it is not currently up/open
  # * running a functional test of the tunnel
  def is_available_via_ssh?

    if @ssh.nil? or @ssh.closed?
      begin
        self.connect_ssh_tunnel()
      rescue Rouster::InternalError, Net::SSH::Disconnect => e
        return false
      end

    end

    begin
      self.run('echo functional test of SSH tunnel')
    rescue
      return false
    end

    true
  end

  ##
  # get_ssh_info - shells out and runs 'vagrant ssh-config <name>' from the Vagrantfile path
  #
  # returns a hash containing required data for opening an SSH connection to a VM
  def get_ssh_info

    h = Hash.new()

    if @ssh_info.class.eql?(Hash)
      h = @ssh_info
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

      @ssh_info = h
    end

    h
  end

  ##
  # connect_ssh_tunnel - instantiates a Net::SSH persistent connection to the Vagrant VM
  #
  # raises its own exception if the machine isn't running, otherwise returns Net::SSH connection object
  def connect_ssh_tunnel
    @log.debug('opening SSH tunnel..')

    if self.status.eql?('running')
      self.get_ssh_info()
      @ssh = Net::SSH.start(@ssh_info[:hostname], @ssh_info[:user], :port => @ssh_info[:ssh_port], :keys => [@sshkey], :paranoid => false)
    else
      raise InternalError.new('VM is not running, unable open SSH tunnel')
    end

    @ssh
  end

  ##
  # os_type - attempts to determine VM operating system based on `uname -a` output, supports OSX, Sun|Solaris, Ubuntu and Redhat
  #
  # parameters
  #  * start_if_not_running - defaults to true, if machine is not running, starts it up
  #
  # if machine is not running and start_if_not_running is disabled, will throw a Rouster::InternalError exception after trying to run() a command
  def os_type(start_if_not_running=true)

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

  ##
  # get - downloads a file from VM to host
  #
  # parameters
  # * <remote_file> - full or relative path (based on ~vagrant) of file to download
  # * [local_file] - full or relative path (based on $PWD) of file to download to
  #
  # if no local_file is specified, will be downloaded to $PWD with the same shortname as it had in the VM
  def get(remote_file, local_file=nil)
    local_file = local_file.nil? ? File.basename(remote_file) : local_file
    @log.debug(sprintf('scp from VM[%s] to host[%s]', remote_file, local_file))

    # TODO should we do a self.file?(remote_file) test before trying to download?

    begin
      @ssh.scp.download!(remote_file, local_file)
    rescue => e
      raise FileTransferError.new(sprintf('unable to get[%s], exception[%s]', remote_file, e.message()))
    end

  end

  ##
  # put - uploads a file from host to VM
  #
  # parameters
  # * <local_file> - full or relative path (based on $PWD) of file to upload
  # * [remote_file] - full or relative path (based on ~vagrant) of filename to upload to
  def put(local_file, remote_file=nil)
    remote_file = remote_file.nil? ? File.basename(local_file) : remote_file
    @log.debug(sprintf('scp from host[%s] to VM[%s]', local_file, remote_file))

    raise FileTransferError.new(sprintf('unable to put[%s], local file does not exist', local_file)) unless File.file?(local_file)

    begin
      @ssh.scp.upload!(local_file, remote_file)
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

    @ssh, @ssh_info = nil, nil
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
