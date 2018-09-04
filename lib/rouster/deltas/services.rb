

class Rouster
  ##
  # get_services
  #
  # runs an OS appropriate command to gather service information, returns hash:
  # {
  #   serviceN => mode # exists|installed|operational|running|stopped|unsure
  # }
  #
  # parameters
  # * [cache]    - boolean controlling whether data retrieved/parsed is cached, defaults to true
  # * [humanize] - boolean controlling whether data retrieved is massaged into simplified names or returned mostly as retrieved
  # * [type]     - symbol indicating which service controller to query, defaults to :all
  # * [seed]     - test hook to seed the output of service commands
  #
  # supported OS and types
  # * OSX     - :launchd
  # * RedHat  - :systemv or :upstart
  # * Solaris - :smf
  # * Ubuntu  - :systemv or :upstart
  #
  # notes
  # * raises InternalError if unsupported operating system
  # * OSX, Solaris and Ubuntu/Debian will only return running|stopped|unsure, the exists|installed|operational modes are RHEL/CentOS only

  def get_services(cache=true, humanize=true, type=:all, seed=nil)
    if cache and ! self.deltas[:services].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:services]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [services] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:services]), self.cache_timeout))
        self.deltas.delete(:services)
      else
        @logger.debug(sprintf('using cached [services] from [%s]', self.cache[:services]))
        return self.deltas[:services]
      end

    end

    res = Hash.new()
    os  = self.os_type

    commands = {
        :osx => {
            :launchd => 'launchctl list',
        },
        :solaris => {
            :smf => 'svcs -a',
        },

        # TODO we really need to implement something like osfamily
        :ubuntu => {
            :systemv => 'service --status-all 2>&1',
            :upstart => 'initctl list',
        },
        :debian => {
            :systemv => 'service --status-all 2>&1',
            :upstart => 'initctl list',
        },
        :rhel => {
            :systemd => 'systemctl list-units --type=service --no-pager',
            :systemv => 'service --status-all',
            :upstart => 'initctl list',
        },

        :invalid => {
            :invalid => 'invalid',
        },
    }

    if type.eql?(:all)
      type = commands[os].keys
    end

    type = type.class.eql?(Array) ? type : [ type ]

    type.each do |provider|

      raise InternalError.new(sprintf('unable to get service information from VM operating system[%s]', os)) if provider.eql?(:invalid)
      raise ArgumentError.new(sprintf('unable to find command provider[%s] for [%s]', provider, os))  if commands[os][provider].nil?

      unless seed or self.is_in_path?(commands[os][provider].split(' ').first)
        @logger.info(sprintf('skipping provider[%s], not in $PATH[%s]', provider, commands[os][provider]))
        next
      end

      @logger.info(sprintf('get_services using provider [%s] on [%s]', provider, os))

      # TODO while this is true, what if self.user is 'root'.. -- the problem is we don't have self.user, and we store this data differently depending on self.passthrough?
      @logger.warn('gathering service information typically works better with sudo, which is currently not being used') unless self.uses_sudo?

      # TODO come up with a better test hook -- real problem is that we can't seed 'raw' with different values per iteration
      raw = seed.nil? ? self.run(commands[os][provider]) : seed

      if os.eql?(:osx)

        raw.split("\n").each do |line|
          next if line.match(/(?:\S*?)\s+(\S*?)\s+(\S+)$/).nil?
          tokens = line.split("\s")
          service = tokens[-1]
          mode    = tokens[0]

          if humanize # should we do this with a .freeze instead?
            if mode.match(/^\d/)
              mode = 'running'
            elsif mode.match(/-/)
              mode = 'stopped'
            else
              next # this should handle the banner "PID     Status  Label"
            end
          end

          res[service] = mode
        end

      elsif os.eql?(:solaris)

        raw.split("\n").each do |line|
          next if line.match(/(.*?)\s+(?:.*?)\s+(.*?)$/).nil?

          service = $2
          mode    = $1

          if humanize
            if mode.match(/^online/)
              mode = 'running'
            elsif mode.match(/^legacy_run/)
              mode = 'running'
            elsif mode.match(/^disabled/)
              mode = 'stopped'
            end

            if service.match(/^svc:\/.*\/(.*?):.*/)
              # turning 'svc:/network/cswpuppetd:default' into 'cswpuppetd'
              service = $1
            elsif service.match(/^lrc:\/.*?\/.*\/(.*)/)
              # turning 'lrc:/etc/rcS_d/S50sk98Sol' into 'S50sk98Sol'
              service = $1
            end
          end

          res[service] = mode

        end

      elsif os.eql?(:ubuntu) or os.eql?(:debian)

        raw.split("\n").each do |line|
          if provider.eql?(:systemv)
            next if line.match(/\[(.*?)\]\s+(.*)$/).nil?
            mode    = $1
            service = $2

            if humanize
              mode = 'stopped' if mode.match('-')
              mode = 'running' if mode.match('\+')
              mode = 'unsure'  if mode.match('\?')
            end

            res[service] = mode
          elsif provider.eql?(:upstart)
            if line.match(/(.*?)\s.*?(.*?),/)
              # tty (/dev/tty3) start/running, process 1601
              # named start/running, process 8959
              service = $1
              mode    = $2
            elsif line.match(/(.*?)\s(.*)/)
              # rcS stop/waiting
              service = $1
              mode    = $2
            else
              @logger.warn("unable to process upstart line[#{line}], skipping")
              next
            end

            if humanize
              mode = 'stopped' if mode.match('stop/waiting')
              mode = 'running' if mode.match('start/running')
              mode = 'unsure'  unless mode.eql?('stopped') or mode.eql?('running')
            end

            res[service] = mode
          end
        end

      elsif os.eql?(:rhel)

        raw.split("\n").each do |line|
          if provider.eql?(:systemv)
            if humanize
              if line.match(/^(\w+?)\sis\s(.*)$/)
                # <service> is <state>
                name = $1
                state = $2
                res[name] = state

                if state.match(/^not/)
                  # this catches 'Kdump is not operational'
                  res[name] = 'stopped'
                end

              elsif line.match(/^(\w+?)\s\(pid.*?\)\sis\s(\w+)$/)
                # <service> (pid <pid> [pid]) is <state>...
                res[$1] = $2
              elsif line.match(/^(\w+?)\sis\s(\w+)\.*$/) # not sure this is actually needed
                @logger.debug('triggered supposedly unnecessary regex')
                # <service> is <state>. whatever
                res[$1] = $2
              elsif line.match(/razor_daemon:\s(\w+).*$/)
                # razor_daemon: running [pid 11325]
                # razor_daemon: no instances running
                res['razor_daemon'] = $1.eql?('running') ? $1 : 'stopped'
              elsif line.match(/^(\w+?)\:.*?(\w+)$/)
                # <service>: whatever <state>
                res[$1] = $2
              elsif line.match(/^(\w+?):.*?\sis\snot\srunning\.$/)
                # ip6tables: Firewall is not running.
                res[$1] = 'stopped'
              elsif line.match(/Chain [A-Z]+ \(policy ACCEPT\)/)
                # see https://github.com/chorankates/rouster/issues/84
                res['iptables'] = 'running'
              elsif line.match(/^(\w+?)\s.*?\s(.*)$/)
                # netconsole module not loaded
                res[$1] = $2.match(/not/) ? 'stopped' : 'running'
              elsif line.match(/^(\w+)\s(\w+).*$/)
                # <process> <state> whatever
                res[$1] = $2
              else
                # original regex implementation, if we didn't match anything else, failover to this
                next if line.match(/^([^\s:]*).*\s(\w*)(?:\.?){3}$/).nil?
                res[$1] = $2
              end
            else
              next if line.match(/^([^\s:]*).*\s(\w*)(?:\.?){3}$/).nil?
              res[$1] = $2
            end
          elsif provider.eql?(:upstart)

            if line.match(/(.*?)\s.*?(.*?),/)
              # tty (/dev/tty3) start/running, process 1601
              # named start/running, process 8959
              service = $1
              mode    = $2
            elsif line.match(/(.*?)\s(.*)/)
              # rcS stop/waiting
              service = $1
              mode    = $2
            else
              @logger.warn("unable to process upstart line[#{line}], skipping")
              next
            end

            if humanize
              mode = 'stopped' if mode.match('stop/waiting')
              mode = 'running' if mode.match('start/running')
              mode = 'unsure'  unless mode.eql?('stopped') or mode.eql?('running')
            end

            res[service] = mode unless res.has_key?(service)

          elsif provider.eql?(:systemd)
            # UNIT              LOAD   ACTIVE   SUB      DESCRIPTION
            # nfs-utils.service loaded inactive dead     NFS server and client services
            # crond.service     loaded active   running  Command Scheduler

            if line.match(/^\W*(.*?)\.service\s+(?:.*?)\s+(.*?)\s+(.*?)\s+(?:.*?)$/) # 5 space separated characters
              service = $1
              active  = $2
              sub     = $3

              if humanize
                mode = sub.match('running') ? 'running' : 'stopped'
                mode = 'unsure'  unless mode.eql?('stopped') or mode.eql?('running')
              end

              res[service] = mode
            else
              # not logging here, there is a bunch of garbage output at the end of the output that we can't seem to suppress
              next
            end

          end

        end
      else
        raise InternalError.new(sprintf('unable to get service information from VM operating system[%s]', os))
      end


      # end of provider processing
    end

    # issue #63 handling
    # TODO should we consider using symbols here instead?
    allowed_modes = %w(exists installed operational running stopped unsure)
    failover_mode = 'unsure'

    if humanize
      res.each_pair do |k,v|
        next if allowed_modes.member?(v)
        @logger.debug(sprintf('replacing service[%s] status of [%s] with [%s] for uniformity', k, v, failover_mode))
        res[k] = failover_mode
      end
    end

    if cache
      @logger.debug(sprintf('caching [services] at [%s]', Time.now.asctime))
      self.deltas[:services] = res
      self.cache[:services]  = Time.now.to_i
    end

    res
  end
end