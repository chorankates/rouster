require 'rubygems'
require 'log4r'
require 'json'
require 'net/scp'
require 'net/ssh'

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/tests'
require 'rouster/vagrant'

class Rouster

  # sporadically updated version number
  VERSION = 0.57

  # custom exceptions -- what else do we want them to include/do?
  class ArgumentError        < StandardError; end # thrown by methods that take parameters from users
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class ExternalError        < StandardError; end # thrown when external dependencies do not respond as expected
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class PassthroughError     < StandardError; end # thrown by anything Passthrough related (mostly vagrant.rb)
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_accessor :facts
  attr_reader :cache, :cache_timeout, :deltas, :exitcode, :logger, :name, :output, :passthrough, :retries, :sshkey, :unittest, :vagrantbinary, :vagrantfile

  ##
  # initialize - object instantiation
  #
  # parameters
  # * <name>                - the name of the VM as specified in the Vagrantfile
  # * [cache_timeout]       - integer specifying how long Rouster should cache status() and is_available_via_ssh?() results, default is false
  # * [logfile]             - allows logging to an external file, if passed true, generates a dynamic filename, otherwise uses what is passed, default is false
  # * [passthrough]         - boolean of whether this is a VM or passthrough, default is false -- passthrough is not completely implemented
  # * [retries]             - integer specifying number of retries Rouster should attempt when running external (currently only vagrant()) commands
  # * [sshkey]              - the full or relative path to a SSH key used to auth to VM -- defaults to location Vagrant installs to (ENV[VAGRANT_HOME} or ]~/.vagrant.d/)
  # * [sshtunnel]           - boolean of whether or not to instantiate the SSH tunnel upon upping the VM, default is true
  # * [sudo]                - boolean of whether or not to prefix commands run in VM with 'sudo', default is true
  # * [vagrantfile]         - the full or relative path to the Vagrantfile to use, if not specified, will look for one in 5 directories above current location
  # * [vagrant_concurrency] - boolean controlling whether Rouster will attempt to run `vagrant *` if another vagrant process is already running, default is false
  # * [verbosity]           - an integer representing console level logging, or an array of integers representing console,file level logging - DEBUG (0) < INFO (1) < WARN (2) < ERROR (3) < FATAL (4)
  def initialize(opts = nil)
    @cache_timeout       = opts[:cache_timeout].nil? ? false : opts[:cache_timeout]
    @logfile             = opts[:logfile].nil? ? false : opts[:logfile]
    @name                = opts[:name]
    @passthrough         = opts[:passthrough].nil? ? false : opts[:passthrough]
    @retries             = opts[:retries].nil? ? 0 : opts[:retries]
    @sshkey              = opts[:sshkey]
    @sshtunnel           = opts[:sshtunnel].nil? ? true : opts[:sshtunnel]
    @unittest            = opts[:unittest].nil? ? false : opts[:unittest]
    @vagrantfile         = opts[:vagrantfile].nil? ? traverse_up(Dir.pwd, 'Vagrantfile', 5) : opts[:vagrantfile]
    @vagrant_concurrency = opts[:vagrant_concurrency].nil? ? false : opts[:vagrant_concurrency]

    # TODO kind of want to invert this, 0 = trace, 1 = debug, 2 = info, 3 = warning, 4 = error
    # could do `fixed_ordering = [4, 3, 2, 1, 0]` and use user input as index instead, so an input of 4 (which should be more verbose), yields 0
    if opts[:verbosity]
      # TODO decide how to handle this case -- currently #2 is implemented
      # - option 1, if passed a single integer, use that level for both loggers
      # - option 2, if passed a single integer, use that level for stdout, and a hardcoded level (probably INFO) to logfile

      # kind of want to do if opts[:verbosity].respond_to?(:[]), but for 1.87 compatability, going this way..
      if ! opts[:verbosity].is_a?(Array) or opts[:verbosity].is_a?(Integer)
        @verbosity_console = opts[:verbosity].to_i
        @verbosity_logfile = 2
      elsif opts[:verbosity].is_a?(Array)
        # TODO more error checking here when we are sure this is the right way to go
        @verbosity_console = opts[:verbosity][0].to_i
        @verbosity_logfile = opts[:verbosity][1].to_i
        @logfile = true if @logfile.eql?(false) # overriding the default setting
      end
    else
      @verbosity_console = 3
      @verbosity_logfile = 2 # this is kind of arbitrary, but won't actually be created unless opts[:logfile] is also passed
    end

    if opts.has_key?(:sudo)
      @sudo = opts[:sudo]
    elsif @passthrough.class.eql?(Hash)
      # TODO say something here.. or maybe check to see if our user has passwordless sudo?
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

    @logger            = Log4r::Logger.new(sprintf('rouster:%s', @name))
    @logger.outputters << Log4r::Outputter.stderr
    #@log.outputters << Log4r::Outputter.stdout

    if @logfile
      @logfile = @logfile.eql?(true) ? sprintf('/tmp/rouster-%s.%s.%s.log', @name, Time.now.to_i, $$) : @logfile
      @logger.outputters << Log4r::FileOutputter.new(sprintf('rouster:%s', @name), :filename => @logfile, :level => @verbosity_logfile)
    end

    @logger.outputters[0].level = @verbosity_console # can't set this when instantiating a .std* logger, and want the FileOutputter at a different level

    if @passthrough
      # TODO do better about informing of required specifications, maybe point them to an URL?
      @vagrantbinary = 'vagrant' # hacky fix to is_vagrant_running?() grepping, doesn't need to actually be in $PATH
      if @passthrough.class != Hash
        raise ArgumentError.new('passthrough specification should be hash')
      elsif @passthrough[:type].nil?
        raise ArgumentError.new('passthrough :type must be specified, :local or :remote allowed')
      elsif @passthrough[:type].eql?(:local)
        @sshtunnel = false
        @logger.debug('instantiating a local passthrough worker')
      elsif @passthrough[:type].eql?(:remote)
        raise ArgumentError.new('remote passthrough requires :host specification') if @passthrough[:host].nil?
        raise ArgumentError.new('remote passthrough requires :user specification') if @passthrough[:user].nil?
        raise ArgumentError.new('remote passthrough requires :key specification')  if @passthrough[:key].nil?
        raise ArgumentError.new('remote passthrough requires valid :key specification, should be path to private half') unless File.file?(@passthrough[:key])
        @sshkey = @passthrough[:key] # TODO refactor so that you don't have to do this..
        @logger.debug('instantiating a remote passthrough worker')
      elsif @passthrough[:type].eql?(:aws)
        # TODO add tests to ensure that user specs are overriding defaults / defaults are used when user specs DNE
        defaults = {
          :ami          => 'ami-7bdaa84b', # RHEL 6.5 x64
          :key          => ENV['AWS_ACCESS_KEY_ID'],
          :min_count    => 1,
          :max_count    => 1,
          :region       => 'us-west-2',
          :secret       => ENV['AWS_SECRET_ACCESS_KEY'],
          :size         => 't1.micro',
          :sshtunnel => false,
          :user         => 'cloud-user',
        }

        @passthrough[:security_groups] = @passthrough[:security_groups].is_a?(Array) ? @passthrough[:security_groups] : [ @passthrough[:security_groups] ]

        @passthrough = defaults.merge(@passthrough)

        [:ami, :size, :user, :region, :sshkey, :keypair, :key, :secret, :security_groups].each do |r|
          raise ArgumentError.new(sprintf('AWS passthrough requires %s specification', r)) if @passthrough[r].nil?
        end

        raise ArgumentError.new('AWS passthrough requires valid :sshkey specification, should be path to private half') unless File.file?(@passthrough[:sshkey])
        @sshkey    = @passthrough[:sshkey]
        @sshtunnel = @passthrough[:sshtunnel] # technically this is supposed to be a top level attribute

      else
        raise ArgumentError.new(sprintf('passthrough :type [%s] unknown, allowed: :aws, :local, :remote', @passthrough[:type]))
      end
    else

      @logger.debug('Vagrantfile and VM name validation..')
      unless File.file?(@vagrantfile)
        raise ArgumentError.new(sprintf('specified Vagrantfile [%s] does not exist', @vagrantfile))
      end

      raise ArgumentError.new('name of Vagrant VM not specified') if @name.nil?

      return if opts[:unittest].eql?(true) # quick return if we're a unit test

      begin
        @vagrantbinary = self._run('which vagrant').chomp!
      rescue
        raise ExternalError.new('vagrant not found in path')
      end

      @logger.debug('SSH key discovery and viability tests..')
      if @sshkey.nil?
        # ref the key from the vagrant home dir if it's been overridden
        @sshkey = sprintf('%s/insecure_private_key', ENV['VAGRANT_HOME']) if ENV['VAGRANT_HOME']
        @sshkey = sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']) unless ENV['VAGRANT_HOME']
      end
    end

    # this is breaking test/functional/test_caching.rb test_ssh_caching (if the VM was not running when the test started)
    # it slows down object instantiation, but is a good test to ensure the machine name is valid..
    begin
      self.status()
    rescue Rouster::LocalExecutionError => e
      raise InternalError.new(sprintf('caught non-0 exitcode from status(): %s', e.message))
    end

    begin
      raise InternalError.new('ssh key not specified') if @sshkey.nil?
      raise InternalError.new('ssh key does not exist') unless File.file?(@sshkey)
      self.check_key_permissions(@sshkey)
    rescue => e

      unless self.is_passthrough? and @passthrough[:type].eql?(:local)
        raise InternalError.new("specified key [#{@sshkey}] has bad permissions. Vagrant exception: [#{e.message}]")
      end

    end

    if @sshtunnel
      self.up()
    end

    @logger.info('Rouster object successfully instantiated')
  end


  ##
  # inspect
  #
  # overloaded method to return useful information about Rouster objects
  def inspect
    s = self.status()
    "name [#{@name}]:
      is_available_via_ssh?[#{self.is_available_via_ssh?}],
      passthrough[#{@passthrough}],
      sshkey[#{@sshkey}],
      status[#{s}],
      sudo[#{@sudo}],
      vagrantfile[#{@vagrantfile}],
      verbosity console[#{@verbosity_console}] / log[#{@verbosity_logfile} - #{@logfile}]\n"
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
    @logger.info(sprintf('vm running: [%s]', cmd)) # TODO decide whether this should be changed in light of passthroughs.. 'remotely'?

    0.upto(@retries) do |try|
      begin
        if self.is_passthrough? and self.passthrough[:type].eql?(:local)
          output = `#{cmd}`
        else
          output = @ssh.exec!(cmd)
        end

        break
      rescue => e
        @logger.error(sprintf('failed to run [%s] with [%s], attempt[%s/%s]', cmd, e, try, retries)) if self.retries > 0
        sleep 10 # TODO need to expose this as a variable
      end

    end

    if output.nil?
      output    = "error gathering output, last logged output[#{self.get_output()}]"
      @exitcode = 256
    elsif output.match(/ec\[(\d+)\]/)
      @exitcode = $1.to_i
      output.gsub!(/ec\[(\d+)\]\n/, '')
    else
      @exitcode = 1
    end

    self.output.push(output)
    @logger.debug(sprintf('output: [%s]', output))

    unless expected_exitcode.member?(@exitcode)
      # TODO technically this could be a 'LocalPassthroughExecutionError' now too if local passthrough.. should we update?
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
          @logger.debug(sprintf('using cached is_available_via_ssh?[%s] from [%s]', @cache[:is_available_via_ssh?][:status], @cache[:is_available_via_ssh?][:time]))
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
      @logger.debug(sprintf('caching is_available_via_ssh?[%s] at [%s]', @cache[:is_available_via_ssh?][:status], @cache[:is_available_via_ssh?][:time]))
    end

    res
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
      @logger.debug('using cached SSH info')
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
          key = $1
          unless @sshkey.eql?(key)
            h[:identity_file] = key
          else
            @logger.info(sprintf('using specified key[%s] instead of discovered key[%s]', @sshkey, key))
            h[:identity_file] = @sshkey
          end

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

    if self.is_passthrough?
      if self.passthrough[:type].eql?(:local)
        return false
      else
        @logger.debug('opening remote SSH tunnel..')
        @ssh = Net::SSH.start(
          @passthrough[:host],
          @passthrough[:user],
          :port => @passthrough[:port],
          :keys => [ @passthrough[:key] ],
          :paranoid => false
        )
      end
    else
      # not a passthrough, normal connection
      status = self.status()

      if status.eql?('running')
        self.get_ssh_info()
        @logger.debug('opening VM SSH tunnel..')
        @ssh = Net::SSH.start(
          @ssh_info[:hostname],
          @ssh_info[:user],
          :port => @ssh_info[:ssh_port],
          :keys => [@sshkey],
          :paranoid => false
        )
      else
        raise InternalError.new(sprintf('VM is not running[%s], unable open SSH tunnel', status))
      end
    end

    @ssh
  end

  ##
  # disconnect_ssh_tunnel
  #
  # shuts down the persistent Net::SSH tunnel
  #
  def disconnect_ssh_tunnel
    @logger.debug('closing SSH tunnel..')

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

    # TODO switch to file based detection
    # Ubuntu - /etc/os-release
    # Solaris - /etc/release
    # RHEL/CentOS - /etc/redhat-release
    # OSX - ?

    res   = nil
    uname = self.run('uname -a')

    case uname
      when /Darwin/i
        res = :osx
      when /SunOS|Solaris/i
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
    @logger.debug(sprintf('scp from VM[%s] to host[%s]', remote_file, local_file))

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
    @logger.debug(sprintf('scp from host[%s] to VM[%s]', local_file, remote_file))

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
    @passthrough.class.eql?(Hash)
  end

  ##
  # uses_sudo?
  #
  # convenience getter for @sudo truthiness
  def uses_sudo?
     @sudo.eql?(true)
  end

  ##
  # rebuild
  #
  # destroy and then up the machine in question
  def rebuild
    @logger.debug('rebuild()')
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
    @logger.debug('restart()')

    if self.is_passthrough? and self.passthrough[:type].eql?(:local)
      @logger.warn(sprintf('intercepted [restart] sent to a local passthrough, no op'))
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
        @logger.debug(sprintf('waiting for reboot: round[%s], step[%s], total[%s]', e, inc, wait))
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
    tmp_file = sprintf('/tmp/rouster-cmd_output.%s.%s', Time.now.to_i, $$)
    cmd      = sprintf('%s > %s 2> %s', command, tmp_file, tmp_file) # this is a holdover from Salesforce::Vagrant, can we use '2&>1' here?
    res      = `#{cmd}` # what does this actually hold?

    @logger.info(sprintf('host running: [%s]', cmd))

    output = File.read(tmp_file)
    File.delete(tmp_file) or raise InternalError.new(sprintf('unable to delete [%s]: %s', tmp_file, $!))

    self.output.push(output)
    @logger.debug(sprintf('output: [%s]', output))

    unless $?.success?
      raise LocalExecutionError.new(sprintf('command [%s] exited with code [%s], output [%s]', cmd, $?.to_i(), output))
    end

    @exitcode = $?.to_i()
    output
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

    @logger.debug(sprintf('traverse_up() looking for [%s] in [%s], up to [%s] levels', filename, startdir, levels)) unless @logger.nil?

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

    if key.match(/\.pub$/)
      # if this is the public half of the key, be more permissive
      allowed_modes << '0644'
    end

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
