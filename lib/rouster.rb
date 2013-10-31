require 'rubygems'
require 'log4r'
require 'json'
require 'net/scp'
require 'net/ssh'

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/tests'

class Rouster

  # sporadically updated version number
  VERSION = 0.50

  # custom exceptions -- what else do we want them to include/do?
  class ArgumentError        < StandardError; end # thrown by methods that take parameters from users
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class ExternalError        < StandardError; end # thrown when external dependencies do not respond as expected
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_accessor :facts, :sudo, :verbosity
  attr_reader :cache, :cache_timeout, :deltas, :exitcode, :log, :name, :output, :passthrough, :sshkey, :unittest, :vagrantfile

  ##
  # initialize - object instantiation
  #
  # parameters
  # * <name> - the name of the VM as specified in the Vagrantfile
  # * [cache_timeout] - integer specifying how long Rouster should cache status() and is_available_via_ssh?() results, default is false
  # * [passthrough] - boolean of whether this is a VM or passthrough, default is false -- passthrough is not completely implemented
  # * [sshkey] - the full or relative path to a SSH key used to auth to VM -- defaults to location Vagrant installs to (ENV[VAGRANT_HOME} or ]~/.vagrant.d/)
  # * [sshtunnel] - boolean of whether or not to instantiate the SSH tunnel upon upping the VM, default is true
  # * [sudo] - boolean of whether or not to prefix commands run in VM with 'sudo', default is true
  # * [vagrantfile] - the full or relative path to the Vagrantfile to use, if not specified, will look for one in 5 directories above current location
  # * [verbosity] - DEBUG (0) < INFO (1) < WARN (2) < ERROR (3) < FATAL (4)
  def initialize(opts = nil)
    @cache_timeout = opts[:cache_timeout].nil? ? false : opts[:cache_timeout]
    @name          = opts[:name]
    @passthrough   = opts[:passthrough].nil? ? false : opts[:passthrough]
    @sshkey        = opts[:sshkey]
    @sshtunnel     = opts[:sshtunnel].nil? ? true : opts[:sshtunnel]
    @unittest      = opts[:unittest].nil? ? false : opts[:unittest]
    @vagrantfile   = opts[:vagrantfile].nil? ? traverse_up(Dir.pwd, 'Vagrantfile', 5) : opts[:vagrantfile]
    @verbosity     = opts[:verbosity].is_a?(Integer) ? opts[:verbosity] : 4

    if opts.has_key?(:sudo)
      @sudo = opts[:sudo]
    elsif @passthrough.eql?(true)
      @sudo = false
    else
      @sudo = true
    end

    @ostype = nil
    @output = Array.new
    @cache  = Hash.new
    @deltas = Hash.new

    @exitcode = nil
    @ssh      = nil # hash containing the SSH connection object
    @ssh_info = nil # hash containing connection information

    # set up logging
    require 'log4r/config'
    Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

    @log            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @log.outputters = Log4r::Outputter.stderr
    @log.level      = @verbosity

    @log.debug('Vagrantfile and VM name validation..')
    unless File.file?(@vagrantfile)
      raise InternalError.new(sprintf('specified Vagrantfile [%s] does not exist', @vagrantfile))
    end

    raise InternalError.new('name of Vagrant VM not specified') if @name.nil?

    return if opts[:unittest].eql?(true) # quick return if we're a unit test

    # this is breaking test/functional/test_caching.rb test_ssh_caching (if the VM was not running when the test started)
    # it slows down object instantiation, but is a good test to ensure the machine name is valid..
    begin
      self.status()
    rescue Rouster::LocalExecutionError => e
      raise InternalError.new(sprintf('caught non-0 exitcode from status(): %s', e.message))
    end

    begin
      self._run('which vagrant')
    rescue
      raise ExternalError.new('vagrant not found in path')
    end

    @log.debug('SSH key discovery and viability tests..')
    if @sshkey.nil?
      if @passthrough.eql?(true)
        raise InternalError.new('must specify sshkey when using a passthrough host')
      else
        # ref the key from the vagrant home dir if it's been overridden
        @sshkey = sprintf('%s/insecure_private_key', ENV['VAGRANT_HOME']) if ENV['VAGRANT_HOME']
        @sshkey = sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']) unless ENV['VAGRANT_HOME']
      end
    end

    begin
      raise InternalError.new('ssh key not specified') if @sshkey.nil?
      raise InternalError.new('ssh key does not exist') unless File.file?(@sshkey)
      self.check_key_permissions(@sshkey)
    rescue => e
      raise InternalError.new("specified key [#{@sshkey}] has bad permissions. Vagrant exception: [#{e.message}]")
    end

    if @sshtunnel
      self.up()
    end

    @log.info('Rouster object successfully instantiated')
  end


  ##
  # inspect
  #
  # overloaded method to return useful information about Rouster objects
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
  # up
  # runs `vagrant up` from the Vagrantfile path
  # if :sshtunnel is passed to the object during instantiation, the tunnel is created here as well
  def up
    @log.info('up()')
    self.vagrant(sprintf('up %s', @name))

    @ssh_info = nil # in case the ssh-info has changed, a la destroy/rebuild
    self.connect_ssh_tunnel() if @sshtunnel
  end

  ##
  # destroy
  # runs `vagrant destroy <name>` from the Vagrantfile path
  def destroy
    @log.info('destroy()')
    disconnect_ssh_tunnel
    self.vagrant(sprintf('destroy -f %s', @name))
  end

  ##
  # status
  #
  # runs `vagrant status <name>` from the Vagrantfile path
  # parses the status and provider out of output, but only status is returned
  def status
    status = nil

    if @cache_timeout
      if @cache.has_key?(:status)
        if (Time.now.to_i - @cache[:status][:time]) < @cache_timeout
          @log.debug(sprintf('using cached status[%s] from [%s]', @cache[:status][:status], @cache[:status][:time]))
          return @cache[:status][:status]
        end
      end
    end

    @log.info('status()')
    self.vagrant(sprintf('status %s', @name))

    # else case here is handled by non-0 exit code
    if self.get_output().match(/^#{@name}\s*(.*\s?\w+)\s\((.+)\)$/)
      # vagrant 1.2+, $1 = status, $2 = provider
      status = $1
    elsif self.get_output().match(/^#{@name}\s+(.+)$/)
      # vagrant 1.2-, $1 = status
      status = $1
    end

    if @cache_timeout
      @cache[:status] = Hash.new unless @cache[:status].class.eql?(Hash)
      @cache[:status][:time] = Time.now.to_i
      @cache[:status][:status] = status
      @log.debug(sprintf('caching status[%s] at [%s]', @cache[:status][:status], @cache[:status][:time]))
    end

    return status
  end

  ##
  # suspend
  #
  # runs `vagrant suspend <name>` from the Vagrantfile path
  def suspend
    @log.info('suspend()')
    disconnect_ssh_tunnel()
    self.vagrant(sprintf('suspend %s', @name))
  end

  ## internal methods
  #private -- commented out so that unit tests can pass, should probably use the 'make all private methods public' method discussed in issue #28

  ##
  # run
  #
  # runs a command inside the Vagrant VM
  #
  # returns output (STDOUT and STDERR) from command run, sets @exitcode
  # currently determines exitcode by tacking a 'echo $?' onto the command being run, which is then parsed out before returning
  #
  # parameters
  # * <command> - the command to run (sudo will be prepended if specified in object instantiation)
  # * [expected_exitcode] - allows for non-0 exit codes to be returned without requiring exception handling
  def run(command, expected_exitcode=[0])

    if @ssh.nil?
      self.connect_ssh_tunnel
    end

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
    @log.debug(sprintf('output: [%s]', output))

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
    res = nil

    if @cache_timeout
      if @cache.has_key?(:is_available_via_ssh?)
        if (Time.now.to_i - @cache[:is_available_via_ssh?][:time]) < @cache_timeout
          @log.debug(sprintf('using cached is_available_via_ssh?[%s] from [%s]', @cache[:is_available_via_ssh?][:status], @cache[:is_available_via_ssh?][:time]))
          return @cache[:is_available_via_ssh?][:status]
        end
      end
    end

    if @ssh.nil? or @ssh.closed?
      begin
        self.connect_ssh_tunnel()
      rescue Rouster::InternalError, Net::SSH::Disconnect => e
        res = false
      end

    end

    if res.nil?
      begin
        self.run('echo functional test of SSH tunnel')
      rescue
        res = false
      end
    end

    res = true if res.nil?

    if @cache_timeout
      @cache[:is_available_via_ssh?] = Hash.new unless @cache[:is_available_via_ssh?].class.eql?(Hash)
      @cache[:is_available_via_ssh?][:time] = Time.now.to_i
      @cache[:is_available_via_ssh?][:status] = res
      @log.debug(sprintf('caching is_available_via_ssh?[%s] at [%s]', @cache[:is_available_via_ssh?][:status], @cache[:is_available_via_ssh?][:time]))
    end

    res
  end

  ##
  # sandbox_available?
  #
  # returns true or false after attempting to find out if the sandbox
  # subcommand is available
  def sandbox_available?
    if @cache.has_key?(:sandbox_available?)
      @log.debug(sprintf('using cached sandbox_available?[%s]', @cache[:sandbox_available?]))
      return @cache[:sandbox_available?]
    end

    @log.info('sandbox_available()')
    self._run(sprintf('cd %s; vagrant', File.dirname(@vagrantfile))) # calling 'vagrant' without parameters to determine available faces

    sandbox_available = false
    if self.get_output().match(/^\s+sandbox$/)
      sandbox_available = true
    end

    @cache[:sandbox_available?] = sandbox_available
    @log.debug(sprintf('caching sandbox_available?[%s]', @cache[:sandbox_available?]))
    @log.error('sandbox support is not available, please install the "sahara" gem first, https://github.com/jedi4ever/sahara') unless sandbox_available

    return sandbox_available
  end

  ##
  # sandbox_on
  # runs `vagrant sandbox on` from the Vagrantfile path
  def sandbox_on
    if self.sandbox_available?
      return self.vagrant(sprintf('sandbox on %s', @name))
    else
      raise ExternalError.new('sandbox plugin not installed')
    end
  end

  ##
  # sandbox_off
  # runs `vagrant sandbox off` from the Vagrantfile path
  def sandbox_off
    if self.sandbox_available?
      return self.vagrant(sprintf('sandbox off %s', @name))
    else
      raise ExternalError.new('sandbox plugin not installed')
    end
  end

  ##
  # sandbox_rollback
  # runs `vagrant sandbox rollback` from the Vagrantfile path
  def sandbox_rollback
    if self.sandbox_available?
      self.disconnect_ssh_tunnel
      self.vagrant(sprintf('sandbox rollback %s', @name))
      self.connect_ssh_tunnel
    else
      raise ExternalError.new('sandbox plugin not installed')
    end
  end

  ##
  # sandbox_commit
  # runs `vagrant sandbox commit` from the Vagrantfile path
  def sandbox_commit
    if self.sandbox_available?
      self.disconnect_ssh_tunnel
      self.vagrant(sprintf('sandbox commit %s', @name))
      self.connect_ssh_tunnel
    else
      raise ExternalError.new('sandbox plugin not installed')
    end
  end

  ##
  # get_ssh_info
  #
  # runs `vagrant ssh-config <name>` from the Vagrantfile path
  #
  # returns a hash containing required data for opening an SSH connection to a VM, to be consumed by connect_ssh_tunnel()
  def get_ssh_info

    h = Hash.new()

    if @ssh_info.class.eql?(Hash)
      h = @ssh_info
    else

      res = self.vagrant(sprintf('ssh-config %s', @name))

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
  # connect_ssh_tunnel
  #
  # instantiates a Net::SSH persistent connection to the Vagrant VM
  #
  # raises its own InternalError if the machine isn't running, otherwise returns Net::SSH connection object
  def connect_ssh_tunnel
    @log.debug('opening SSH tunnel..')

    status = self.status()
    if status.eql?('running')
      self.get_ssh_info()
      @ssh = Net::SSH.start(@ssh_info[:hostname], @ssh_info[:user], :port => @ssh_info[:ssh_port], :keys => [@sshkey], :paranoid => false)
    else
      raise InternalError.new(sprintf('VM is not running[%s], unable open SSH tunnel', status))
    end

    @ssh
  end

  ##
  # disconnect_ssh_tunnel
  #
  # shuts down the persistent Net::SSH tunnel
  #
  def disconnect_ssh_tunnel
    @log.debug('closing SSH tunnel..')

    @ssh.shutdown! unless @ssh.nil?
    @ssh = nil
  end

  ##
  # os_type
  #
  # attempts to determine VM operating system based on `uname -a` output, supports OSX, Sun|Solaris, Ubuntu and Redhat
  def os_type

    if @ostype
      return @ostype
    end

    res   = nil
    uname = self.run('uname -a')

    case uname
      when /Darwin/i
        res = :osx
      when /Sun|Solaris/i
        res =:solaris
      when /Ubuntu/i
        res = :ubuntu
      when /Debian/i
        res = :debian
      else
        if self.is_file?('/etc/redhat-release')
          res = :redhat
        else
          res = nil
        end
    end

    @ostype = res
    res
  end

  ##
  # get
  #
  # downloads a file from VM to host
  #
  # parameters
  # * <remote_file> - full or relative path (based on ~vagrant) of file to download
  # * [local_file] - full or relative path (based on $PWD) of file to download to
  #
  # if no local_file is specified, will be downloaded to $PWD with the same shortname as it had in the VM
  #
  # returns true on successful download, false if the file DNE and raises a FileTransferError.. well, you know
  def get(remote_file, local_file=nil)
    # TODO what happens when we pass a wildcard as remote_file?

    local_file = local_file.nil? ? File.basename(remote_file) : local_file
    @log.debug(sprintf('scp from VM[%s] to host[%s]', remote_file, local_file))

    begin
      @ssh.scp.download!(remote_file, local_file)
    rescue => e
      raise FileTransferError.new(sprintf('unable to get[%s], exception[%s]', remote_file, e.message()))
    end

    return true
  end

  ##
  # put
  #
  # uploads a file from host to VM
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

  ##
  # is_passthrough?
  #
  # convenience getter for @passthrough truthiness
  def is_passthrough?
    self.passthrough.eql?(true)
  end

  ##
  # uses_sudo?
  #
  # convenience getter for @sudo truthiness
  def uses_sudo?
     self.sudo.eql?(true)
  end

  ##
  # rebuild
  #
  # destroy and then up the machine in question
  def rebuild
    @log.debug('rebuild()')
    self.destroy
    self.up
  end

  ##
  # restart
  #
  # runs `shutdown -rf now` in the VM, optionally waits for machine to come back to life
  #
  # parameters
  # * [wait] - number of seconds to wait until is_available_via_ssh?() returns true before assuming failure
  def restart(wait=nil)
    @log.debug('restart()')

    if self.is_passthrough? and self.passthrough.eql?(local)
      @log.warn(sprintf('intercepted [restart] sent to a local passthrough, no op'))
      return nil
    end

    case os_type
      when :osx
        self.run('shutdown -r now')
      when :redhat, :ubuntu, :debian
        self.run('/sbin/shutdown -rf now')
      when :solaris
        self.run('shutdown -y -i5 -g0')
      else
        raise InternalError.new(sprintf('unsupported OS[%s]', @ostype))
    end

    @ssh, @ssh_info = nil # severing the SSH tunnel, getting ready in case this box is brought back up on a different port

    if wait
      inc = wait.to_i / 10
      0..wait.each do |e|
        @log.debug(sprintf('waiting for reboot: round[%s], step[%s], total[%s]', e, inc, wait))
        return true if self.is_available_via_ssh?()
        sleep inc
      end

      return false
    end

    return true
  end

  ##
  # _run
  #
  # (should be) private method that executes commands on the local host (not guest VM)
  #
  # returns STDOUT|STDERR, raises Rouster::LocalExecutionError on non 0 exit code
  # sets @exitcode
  #
  # parameters
  # * <command> - command to be run
  def _run(command)
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
    @log.debug(sprintf('output: [%s]', output))

    @exitcode = $?.to_i()
    output
  end

  ##
  # vagrant
  #
  # abstraction layer to call vagrant faces
  #
  # parameters
  # * <face> - vagrant face to call (include arguments)
  def vagrant(face)
    self._run(sprintf('cd %s; vagrant %s', File.dirname(@vagrantfile), face))
  end

  ##
  # get_output
  #
  # returns output from commands passed through _run() and run()
  #
  # if no parameter passed, returns output from the last command run
  #
  # parameters
  # * [index] - positive or negative indexing of LIFO datastructure
  def get_output(index = 1)
    index.is_a?(Fixnum) and index > 0 ? self.output[-index] : self.output[index]
  end

  ##
  # generate_unique_mac
  #
  # returns a ~unique, valid MAC
  # ht http://www.commandlinefu.com/commands/view/7242/generate-random-valid-mac-addresses
  #
  # uses prefix 'b88d12' (actually Apple's prefix)
  # uniqueness is not guaranteed, is really more just 'random'
  def generate_unique_mac
    sprintf('b88d12%s', (1..3).map{"%0.2X" % rand(256)}.join('').downcase)
  end

  ##
  # traverse_up
  #
  # overly complex function to find a file (Vagrantfile, in our case) somewhere up the tree
  #
  # returns the first matching filename or nil if none found
  #
  # parameters
  # * [startdir] - directory to start looking in, default is current directory
  # * [filename] - filename you are looking for
  # * [levels]   - number of directory levels to examine, default is 10
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

  ##
  # check_key_permissions
  #
  # checks (and optionally fixes) permissions on the SSH key used to auth to the Vagrant VM
  #
  # parameters
  #  * <key> - full path to SSH key
  #  * [fix] - boolean, if true and required, will attempt to set permissions on key to 0400 - default is false
  def check_key_permissions(key, fix=false)
    allowed_modes = ['0400', '0600']

    raw   = self._run(sprintf('ls -l %s', key))
    perms = self.parse_ls_string(raw)

    unless allowed_modes.member?(perms[:mode])
      if fix.eql?(true)
        self._run(sprintf('chmod 0400 %s', key))
        return check_key_permissions(key, fix)
      else
        raise InternalError.new(sprintf('perms for [%s] are [%s], expecting [%s]', key, perms[:mode], allowed_modes))
      end
    end

    unless perms[:owner].eql?(ENV['USER'])
      if fix.eql?(true)
        self._run(sprintf('chown %s %s', ENV['USER'], key))
        return check_key_permissions(key, fix)
      else
        raise InternalError.new(sprintf('owner for [%s] is [%s], expecting [%s]', key, perms[:owner], ENV['USER']))
      end
    end

    nil
  end

end

class Object
  ##
  # false?
  #
  # convenience method to tell if an object equals false
  def false?
    self.eql?(false)
  end

  ##
  # true?
  #
  # convenience method to tell if an object equals true (think .nil? but more useful)
  def true?
    self.eql?(true)
  end
end
