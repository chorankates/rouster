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
  VERSION = 0.73

  # custom exceptions -- what else do we want them to include/do?
  class ArgumentError        < StandardError; end # thrown by methods that take parameters from users
  class FileTransferError    < StandardError; end # thrown by get() and put()
  class InternalError        < StandardError; end # thrown by most (if not all) Rouster methods
  class ExternalError        < StandardError; end # thrown when external dependencies do not respond as expected
  class LocalExecutionError  < StandardError; end # thrown by _run()
  class RemoteExecutionError < StandardError; end # thrown by run()
  class PassthroughError     < StandardError; end # thrown by anything Passthrough related (mostly vagrant.rb)
  class SSHConnectionError   < StandardError; end # thrown by available_via_ssh() -- and potentially _run()

  attr_accessor :facts, :last_puppet_run
  attr_reader :cache, :cache_timeout, :deltas, :logger, :name, :ssh_stdout, :ssh_stderr, :ssh_exitcode, :passthrough, :retries, :sshkey, :unittest, :vagrantbinary, :vagrantfile

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
  # * [vagrant_reboot]      - particularly sticky systems restart better if Vagrant does it for us, default is false
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
    @vagrant_reboot      = opts[:vagrant_reboot].nil? ? false : opts[:vagrant_reboot]

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

    @ostype    = nil
    @osversion = nil

    @ssh_stdout   = Array.new
    @ssh_stderr   = Array.new
    @ssh_exitcode = Array.new
    @cache        = Hash.new
    @deltas       = Hash.new

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

    if opts.has_key?(:sudo)
      @sudo = opts[:sudo]
    elsif @passthrough.class.eql?(Hash)
      @logger.debug(sprintf('passthrough without sudo specification, defaulting to false'))
      @sudo = false
    else
      @sudo = true
    end

    if @passthrough
      @vagrantbinary = 'vagrant' # hacky fix to is_vagrant_running?() grepping, doesn't need to actually be in $PATH
      @sshtunnel     = opts[:sshtunnel].nil? ? false : @sshtunnel # unless user has specified it, non-local passthroughs default to not open tunnel

      defaults = {
        :paranoid          => false, # valid overrides are: false, true, :very, or :secure
        :ssh_sleep_ceiling => 9,
        :ssh_sleep_time    => 10,
      }

      @passthrough = defaults.merge(@passthrough)

      if @passthrough.class != Hash
        raise ArgumentError.new('passthrough specification should be hash')
      elsif @passthrough[:type].nil?
        raise ArgumentError.new('passthrough :type must be specified, :local, :remote or :aws allowed')
      elsif @passthrough[:type].eql?(:local)
        @logger.debug('instantiating a local passthrough worker')
        @sshtunnel = opts[:sshtunnel].nil? ? true : opts[:sshtunnel] # override default, if local, open immediately

      elsif @passthrough[:type].eql?(:remote)
        @logger.debug('instantiating a remote passthrough worker')

        [:host, :user, :key].each do |r|
          raise ArgumentError.new(sprintf('remote passthrough requires[%s] specification', r)) if @passthrough[r].nil?
        end

        raise ArgumentError.new('remote passthrough requires valid :key specification, should be path to private half') unless File.file?(@passthrough[:key])
        @sshkey = @passthrough[:key] # TODO refactor so that you don't have to do this..

      elsif @passthrough[:type].eql?(:aws) or @passthrough[:type].eql?(:raiden)
        @logger.debug(sprintf('instantiating an %s passthrough worker', @passthrough[:type]))

        aws_defaults = {
          :ami                   => 'ami-7bdaa84b', # RHEL 6.5 x64 in us-west-2
          :dns_propagation_sleep => 30, # how much time to wait after ELB creation before attempting to connect
          :elb_cleanup           => false,
          :key_id                => ENV['AWS_ACCESS_KEY_ID'],
          :min_count             => 1,
          :max_count             => 1,
          :region                => 'us-west-2',
          :secret_key            => ENV['AWS_SECRET_ACCESS_KEY'],
          :size                  => 't1.micro',
          :ssh_port              => 22,
          :user                  => 'ec2-user',
        }

        if @passthrough.has_key?(:ami)
          @logger.debug(':ami specified, will start new EC2 instance')

          @passthrough[:security_groups] = @passthrough[:security_groups].is_a?(Array) ? @passthrough[:security_groups] : [ @passthrough[:security_groups] ]

          @passthrough = aws_defaults.merge(@passthrough)

          [:ami, :size, :user, :region, :key, :keypair, :key_id, :secret_key, :security_groups].each do |r|
            raise ArgumentError.new(sprintf('AWS passthrough requires %s specification', r)) if @passthrough[r].nil?
          end

        elsif @passthrough.has_key?(:instance)
          @logger.debug(':instance specified, will connect to existing EC2 instance')

          @passthrough = aws_defaults.merge(@passthrough)

          if @passthrough[:type].eql?(:aws)
            @passthrough[:host] = self.aws_describe_instance(@passthrough[:instance])['dnsName']
          else
            @passthrough[:host] = self.find_ssh_elb(true)
          end

          [:instance, :key, :user, :host].each do |r|
            raise ArgumentError.new(sprintf('AWS passthrough requires [%s] specification', r)) if @passthrough[r].nil?
          end

        else
          raise ArgumentError.new('AWS passthrough requires either :ami or :instance specification')
        end

        raise ArgumentError.new('AWS passthrough requires valid :sshkey specification, should be path to private half') unless File.file?(@passthrough[:key])
        @sshkey = @passthrough[:key]
      elsif @passthrough[:type].eql?(:openstack)
        @logger.debug(sprintf('instantiating an %s passthrough worker', @passthrough[:type]))
        @sshkey = @passthrough[:key]

        ostack_defaults = {
          :ssh_port => 22,
        }
        @passthrough = ostack_defaults.merge(@passthrough)

        [:openstack_auth_url, :openstack_username, :openstack_tenant, :openstack_api_key,
          :key ].each do |r|
            raise ArgumentError.new(sprintf('OpenStack passthrough requires %s specification', r)) if @passthrough[r].nil?
        end

        if @passthrough.has_key?(:image_ref)
          @logger.debug(':image_ref specified, will start new Nova instance')
        elsif @passthrough.has_key?(:instance)
          @logger.debug(':instance specified, will connect to existing OpenStack instance')
          inst_details = self.ostack_describe_instance(@passthrough[:instance])
          raise ArgumentError.new(sprintf('No such instance found in OpenStack - %s', @passthrough[:instance])) if inst_details.nil?
          inst_details.addresses.each_key do |address_key|
            if defined?(inst_details.addresses[address_key].first['addr'])
              @passthrough[:host] = inst_details.addresses[address_key].first['addr']
              break
            end
          end
        end
      else
        raise ArgumentError.new(sprintf('passthrough :type [%s] unknown, allowed: :aws, :openstack, :local, :remote', @passthrough[:type]))
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
  # returns output (STDOUT and STDERR) from command run, pushes to self.ssh_exitcode
  #
  # parameters
  # * <command>           - the command to run
  # * [expected_exitcode] - allows for non-0 exit codes to be returned without requiring exception handling
  # * [sudo]              - boolean of whether or not to prefix command with 'sudo', default is the value specified in object instantiation'
  def run( command, expected_exitcode = 0, sudo = self.uses_sudo? )

    cmd = {
      :command           => command,
      :sudo              => sudo,
      :stdout            => String.new,
      :stderr            => String.new,
      :expected_exitcode => Array( expected_exitcode ),
      :exitcode          => nil,
      :final_command     => sudo ? sprintf( 'sudo bash -c "%s"', command ) : command,
    }

    if @ssh.nil?
      self.connect_ssh_tunnel
    end

    @logger.info( sprintf( 'vm running: [%s]', cmd[:final_command] ) ) # TODO decide whether this should be changed in light of passthroughs.. 'remotely'?

    0.upto(@retries) do |try|
      begin
        if self.is_passthrough? and self.passthrough[:type].eql?(:local)
          cmd[:stdout]   = `#{cmd[:final_command]}`
          cmd[:exitcode] = $?
        else
          cmd = remote_exec( cmd )
        end
        break
      rescue => e
        @logger.error(sprintf('failed to run [%s] with [%s], attempt[%s/%s]', cmd[:final_command], e, try, retries)) if self.retries > 0
        sleep 10 # TODO need to expose this as a variable
      end
    end

    if cmd[:stdout].nil?
      cmd[:stdout]   = "error gathering output, last logged output:\nSTDOUT: [#{self.get_ssh_stdout}]\nSTDERR: [#{self.get_ssh_stderr}]"
      cmd[:exitcode] = 256
    elsif cmd[:exitcode].nil?
      cmd[:exitcode] = 255
    end

    self.ssh_stdout.push(   cmd[:stdout]   )
    self.ssh_stderr.push(   cmd[:stderr]   )
    self.ssh_exitcode.push( cmd[:exitcode] )
    @logger.debug( sprintf( 'ssh_stdout: [%s]', cmd[:stdout] ) )
    @logger.debug( sprintf( 'ssh_stderr: [%s]', cmd[:stderr] ) )

    unless cmd[:expected_exitcode].member?( cmd[:exitcode] )
      # TODO technically this could be a 'LocalPassthroughExecutionError' now too if local passthrough.. should we update?
      raise RemoteExecutionError.new("stdout[#{cmd[:stdout]}], stderr[#{cmd[:stderr]}], exitcode[#{cmd[:exitcode]}], expected[#{cmd[:expected_exitcode]}]")
    end

    cmd[:stdout]
  end

  def remote_exec( cmd )
    @ssh.open_channel do |channel|
      channel.exec( cmd[:final_command] ) do |_ch, success|
        unless success
          error = "FAILED: couldn't execute command remotely [#{cmd[:final_command]}]"
          @logger.error( error )
          raise RemoteExecutionError.new( error )
        end
        channel.on_data                   { |_ch, data|        cmd[:stdout]  << data           }
        channel.on_extended_data          { |_ch, _type, data| cmd[:stderr]  << data           }
        channel.on_request('exit-status') { |_ch, data|        cmd[:exitcode] = data.read_long }
      end
    end
    @ssh.loop
    cmd
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
        res = self.connect_ssh_tunnel()
      rescue Rouster::InternalError, Net::SSH::Disconnect, Errno::ECONNREFUSED, Errno::ECONNRESET => e
        res = false
      end

    end

    if res.nil? or res.is_a?(Net::SSH::Connection::Session)
      begin
        self.run('echo functional test of SSH tunnel')
          res = true
      rescue
        res = false
      end
    end

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
          h[:identity_file] = $1
          @logger.info(sprintf('vagrant specified key[%s] differs from provided[%s], will use both', @sshkey, h[:identity_file]))
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
      if @passthrough[:type].eql?(:local)
        @logger.debug("local passthroughs don't need ssh tunnel, shell execs are used")
        return false
      elsif @passthrough[:host].nil?
        @logger.info(sprintf('not attempting to connect, no known hostname for[%s]', self.passthrough))
        return false
      else
        ceiling    = @passthrough[:ssh_sleep_ceiling]
        sleep_time = @passthrough[:ssh_sleep_time]

        0.upto(ceiling) do |try|
          @logger.debug(sprintf('opening remote SSH tunnel[%s]..', @passthrough[:host]))
          begin
            @ssh = Net::SSH.start(
              @passthrough[:host],
              @passthrough[:user],
              :port                       => @passthrough[:ssh_port],
              :keys                       => [ @passthrough[:key] ], # TODO this should be @sshkey
              :paranoid                   => false,
              :number_of_password_prompts => 0
            )
            break
          rescue => e
            raise e if try.eql?(ceiling) # eventually want to throw a SocketError
            @logger.debug(sprintf('failed to open tunnel[%s], trying again in %ss', e.message, sleep_time))
            sleep sleep_time
          end
        end
      end
      @logger.debug(sprintf('successfully opened SSH tunnel to[%s]', passthrough[:host]))

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
          :keys => [ @sshkey, @ssh_info[:identity_file] ].uniq, # try to use what the user specified first, but fall back to what vagrant says
          :paranoid => false
        )
      else
        # TODO will we ever hit this? or will we be thrown first?
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

    res = :invalid

    Rouster.os_files.each_pair do |os, f|
      [ f ].flatten.each do |candidate|
        if self.is_file?(candidate)
          next if candidate.eql?('/etc/os-release') and ! self.is_in_file?(candidate, os.to_s, 'i') # CentOS detection
          @logger.debug(sprintf('determined OS to be[%s] via[%s]', os, candidate))
          res = os
        end
      end
      break unless res.eql?(:invalid)
    end

    @logger.error(sprintf('unable to determine OS, looking for[%s]', Rouster.os_files)) if res.eql?(:invalid)

    @ostype = res
    res
  end

  ##
  # os_version
  #
  #
  def os_version(os_type)
    return @osversion if @osversion

    res = :invalid

    [ Rouster.os_files[os_type] ].flatten.each do |candidate|
      if self.is_file?(candidate)
        next if candidate.eql?('/etc/os-release') and ! self.is_in_file?(candidate, os_type.to_s, 'i') # CentOS detection
        contents = self.run(sprintf('cat %s', candidate))
        if os_type.eql?(:ubuntu)
          version = $1 if contents.match(/.*VERSION\="(\d+\.\d+).*"/) # VERSION="13.10, Saucy Salamander"
          res = version unless version.nil?
        elsif os_type.eql?(:rhel)
          version = $1 if contents.match(/.*VERSION\="(\d+)"/) # VERSION="7 (Core)"
          version = $1 if version.nil? and contents.match(/.*(\d+.\d+)/) # CentOS release 6.4 (Final)
          res = version unless version.nil?
        elsif os_type.eql?(:osx)
          version = $1 if contents.match(/<key>ProductVersion<\/key>.*<string>(.*)<\/string>/m) # <key>ProductVersion</key>\n          <string>10.12.1</string>
          res = version unless version.nil?
        end

      end
      break unless res.eql?(:invalid)
    end

    @logger.error(sprintf('unable to determine OS version, looking for[%s]', Rouster.os_files[os_type])) if res.eql?(:invalid)

    @osversion = res

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

    return true
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
  def restart(wait=nil, expected_exitcodes = [0])
    @logger.debug('restart()')

    if self.is_passthrough? and self.passthrough[:type].eql?(:local)
      @logger.warn(sprintf('intercepted [restart] sent to a local passthrough, no op'))
      return nil
    end

    if @vagrant_reboot
      # leading vagrant handle this through 'reload --no-provision'
      self.reload
    else
      # trying to do it ourselves
      case os_type
        when :osx
          self.run('shutdown -r now', expected_exitcodes)
        when :rhel, :ubuntu
          if os_type.eql?(:rhel) and os_version(os_type).match(/7/)
            self.run('shutdown --halt --reboot now', expected_exitcodes << 256)
          else
            self.run('shutdown -rf now')
          end
        when :solaris
          self.run('shutdown -y -i5 -g0', expected_exitcodes)
        else
          raise InternalError.new(sprintf('unsupported OS[%s]', @ostype))
      end
    end

    @ssh, @ssh_info = nil # severing the SSH tunnel, getting ready in case this box is brought back up on a different port

    if wait
      inc = wait.to_i / 10
      0.upto(9) do |e|
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
    
    @logger.debug(sprintf('output: [%s]', output))

    unless $?.success?
      raise LocalExecutionError.new(sprintf('command [%s] exited with code [%s], output [%s]', cmd, $?.to_i(), output))
    end

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
    @logger.warn( 'get_output has been deprecated, please replace with get_ssh_stdout' )
    get_ssh_stdout( index )
  end

  ##
  # get_ssh_stdout
  #
  # returns output from commands passed through _run() and run()
  #
  # if no parameter passed, returns stdout from the last command run
  #
  # parameters
  # * [index] - positive or negative indexing of LIFO datastructure
  def get_ssh_stdout(index = 1)
    index.is_a?(Fixnum) and index > 0 ? self.ssh_stdout[-index] : self.ssh_stdout[index]
  end

  ##
  # get_ssh_stderr
  #
  # returns stderr from commands passed through run()
  #
  # if no parameter passed, returns stderr from the last command run
  #
  # parameters
  # * [index] - positive or negative indexing of LIFO datastructure
  def get_ssh_stderr( index = 1 )
    index.is_a?(Fixnum) and index > 0 ? self.ssh_stderr[-index] : self.ssh_stderr[index]
  end

  ##
  # get_ssh_exitcode
  #
  # returns exitcode from commands passed through run()
  #
  # if no parameter passed, returns exitcode from the last command run
  #
  # parameters
  # * [index] - positive or negative indexing of LIFO datastructure
  def get_ssh_exitcode( index = 1 )
    index.is_a?(Fixnum) and index > 0 ? self.ssh_exitcode[-index] : self.ssh_exitcode[index]
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

  def self.os_files
    {
      :ubuntu  => '/etc/os-release', # debian too
      :solaris => '/etc/release',
      :rhel    => ['/etc/os-release', '/etc/redhat-release'], # and centos
      :osx     => '/System/Library/CoreServices/SystemVersion.plist',
    }
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
