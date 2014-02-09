require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

## Vagrant specific (and related) methods

class Rouster

  ##
  # vagrant
  #
  # abstraction layer to call vagrant faces
  #
  # parameters
  # * <face> - vagrant face to call (include arguments)
  def vagrant(face, sleep_time=10)
    if self.is_passthrough?
      # it is a little odd to just return nil for a vagrant face, but raise an exception for sandbox commits.. should we be raising here? or just logging there?
      @logger.info(sprintf('calling [vagrant %s] on a passthrough host is a noop', face))
      return nil
    end

    unless @vagrant_concurrency.eql?(true)
      # TODO don't (ab|re)use variables
      0.upto(@retries) do |try|
        break if self.is_vagrant_running?().eql?(false)

        sleep sleep_time # TODO log a message?
      end
    end

    0.upto(@retries) do |try| # TODO should really be doing this with 'retry', but i think this code is actually cleaner
      begin
        return self._run(sprintf('cd %s; vagrant %s', File.dirname(@vagrantfile), face))
      rescue
        @logger.error(sprintf('failed vagrant command[%s], attempt[%s/%s]', face, try, retries)) if self.retries > 0
        sleep sleep_time
      end
    end

    raise InternalError.new(sprintf('failed to execute [%s], exitcode[%s], output[%s]', face, self.exitcode, self.get_output()))


  end

  ##
  # up
  # runs `vagrant up` from the Vagrantfile path
  # if :sshtunnel is passed to the object during instantiation, the tunnel is created here as well
  def up
    @logger.info('up()')
    self.vagrant(sprintf('up %s', @name))

    @ssh_info = nil # in case the ssh-info has changed, a la destroy/rebuild
    self.connect_ssh_tunnel() if @sshtunnel
  end

  ##
  # destroy
  # runs `vagrant destroy <name>` from the Vagrantfile path
  def destroy
    @logger.info('destroy()')
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
          @logger.debug(sprintf('using cached status[%s] from [%s]', @cache[:status][:status], @cache[:status][:time]))
          return @cache[:status][:status]
        end
      end
    end

    @logger.info('status()')
    self.vagrant(sprintf('status %s', @name))

    # else case here is handled by non-0 exit code
    if self.get_output().nil?
      # should only see this for passthroughs -- we're hitting this, but not seeing it in .inspect output
      status = 'running'
    elsif self.get_output().match(/^#{@name}\s*(.*\s?\w+)\s\((.+)\)$/)
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
      @logger.debug(sprintf('caching status[%s] at [%s]', @cache[:status][:status], @cache[:status][:time]))
    end

    return status
  end

  ##
  # suspend
  #
  # runs `vagrant suspend <name>` from the Vagrantfile path
  def suspend
    @logger.info('suspend()')
    disconnect_ssh_tunnel()
    self.vagrant(sprintf('suspend %s', @name))
  end

  ##
  # is_vagrant_running?()
  #
  # returns true|false if a vagrant process is running on the host machine
  #
  # meant to be used to prevent race-y conditions when interacting with VirtualBox (potentially others, haven't tested)
  def is_vagrant_running?
    res = false

    begin
      # TODO would like to get the 2 -v greps into a single call..
      raw = self._run("ps -ef | grep -v 'grep' | grep -v 'ssh' | grep '#{self.vagrantbinary}'")
      res = true
    rescue
    end

    @logger.debug(sprintf('is_vagrant_running?[%s]', res))
    res
  end

  ##
  # sandbox_available?
  #
  # returns true or false after attempting to find out if the sandbox
  # subcommand is available
  def sandbox_available?
    raise PassthroughError if self.is_passthrough?()

    if @cache.has_key?(:sandbox_available?)
      @logger.debug(sprintf('using cached sandbox_available?[%s]', @cache[:sandbox_available?]))
      return @cache[:sandbox_available?]
    end

    require 'debugger'; debugger
    @logger.info('sandbox_available()')
    begin
      # at some point, vagrant changed its behavior on exit code here, so rescuing
      self._run(sprintf('cd %s; vagrant', File.dirname(@vagrantfile))) # calling 'vagrant' without parameters to determine available faces
    rescue
    end

    sandbox_available = false
    if self.get_output().match(/^\s+sandbox$/)
      sandbox_available = true
    end

    @cache[:sandbox_available?] = sandbox_available
    @logger.debug(sprintf('caching sandbox_available?[%s]', @cache[:sandbox_available?]))
    @logger.error('sandbox support is not available, please install the "sahara" gem first, https://github.com/jedi4ever/sahara') unless sandbox_available

    return sandbox_available
  end

  ##
  # sandbox_on
  # runs `vagrant sandbox on` from the Vagrantfile path
  def sandbox_on
    raise PassthroughError if self.is_passthrough?()

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
    raise PassthroughError if self.is_passthrough?()

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
    raise PassthroughError if self.is_passthrough?()

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
    raise PassthroughError if self.is_passthrough?()

    if self.sandbox_available?
      self.disconnect_ssh_tunnel
      self.vagrant(sprintf('sandbox commit %s', @name))
      self.connect_ssh_tunnel
    else
      raise ExternalError.new('sandbox plugin not installed')
    end
  end


end