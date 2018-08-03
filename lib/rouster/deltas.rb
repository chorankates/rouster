require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# deltas.rb - get information about crontabs, groups, packages, ports, services and users inside a Vagrant VM
require 'rouster'
require 'rouster/tests'

class Rouster

  ##
  # get_crontab
  #
  # runs `crontab -l <user>` and parses output, returns hash:
  # {
  #   user => {
  #     command => {
  #       :minute => minute,
  #       :hour   => hour,
  #       :dom    => dom, # day of month
  #       :mon    => mon, # month
  #       :dow    => dow, # day of week
  #     }
  #   }
  # }
  #
  # the hash will contain integers (not strings) for numerical values -- all but '*'
  #
  # parameters
  # * <user> - name of user who owns crontab for examination -- or '*' to determine list of users and iterate over them to find all cron jobs
  # * [cache] - boolean controlling whether or not retrieved/parsed data is cached, defaults to true
  def get_crontab(user='root', cache=true)

    if cache and self.deltas[:crontab].class.eql?(Hash)

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:crontab]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [crontab] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:crontab]), self.cache_timeout))
        self.deltas.delete(:crontab)
      end

      if self.deltas.has_key?(:crontab) and self.deltas[:crontab].has_key?(user)
        @logger.debug(sprintf('using cached [crontab] from [%s]', self.cache[:crontab]))
        return self.deltas[:crontab][user]
      elsif self.deltas.has_key?(:crontab) and user.eql?('*')
        @logger.debug(sprintf('using cached [crontab] from [%s]', self.cache[:crontab]))
        return self.deltas[:crontab]
      else
        # noop fallthrough to gather data to cache
      end

    end

    res = Hash.new
    users = nil

    if user.eql?('*')
      users = self.get_users().keys
    else
      users = [user]
    end

    users.each do |u|
      begin
        raw = self.run(sprintf('crontab -u %s -l', u))
      rescue RemoteExecutionError => e
        # crontab throws a non-0 exit code if there is no crontab for the specified user
        res[u] ||= Hash.new
        next
      end

      raw.split("\n").each do |line|
        next if line.match(/^#|^\s+$/)
        elements = line.split("\s")

        if elements.size < 5
          # this is usually (only?) caused by ENV_VARIABLE=VALUE directives
          @logger.debug(sprintf('line [%s] did not match format expectations for a crontab entry, skipping', line))
          next
        end

        command = elements[5..elements.size].join(' ')

        res[u] ||= Hash.new

        if res[u][command].class.eql?(Hash)
          unique = elements.join('')
          command = sprintf('%s-duplicate.%s', command, unique)
          @logger.info(sprintf('duplicate crontab command found, adding hash key[%s]', command))
        end

        res[u][command]           = Hash.new
        res[u][command][:minute]  = elements[0]
        res[u][command][:hour]    = elements[1]
        res[u][command][:dom]     = elements[2]
        res[u][command][:mon]     = elements[3]
        res[u][command][:dow]     = elements[4]
      end
    end

    if cache
      @logger.debug(sprintf('caching [crontab] at [%s]', Time.now.asctime))

      if ! user.eql?('*')
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab][user] ||= Hash.new
        self.deltas[:crontab][user] = res[user]
      else
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab] = res
      end

      self.cache[:crontab] = Time.now.to_i

    end

    return user.eql?('*') ? res : res[user]
  end

  ##
  # get_groups
  #
  # cats /etc/group and parses output, returns hash:
  # {
  #   groupN => {
  #     :gid => gid,
  #     :users => [user1, userN]
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  # * [deep]  - boolean controlling whether get_users() is called in order to correctly populate res[group][:users]
  def get_groups(cache=true, deep=true)

    if cache and ! self.deltas[:groups].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:groups]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [groups] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:groups]), self.cache_timeout))
        self.deltas.delete(:groups)
      else
        @logger.debug(sprintf('using cached [groups] from [%s]', self.cache[:groups]))
        return self.deltas[:groups]
      end

    end

    res = Hash.new()

    {
      :file    => self.run('cat /etc/group'),
      :dynamic => self.run('getent group', [0,127]),
    }.each_pair do |source, raw|

      raw.split("\n").each do |line|
        next unless line.match(/\w+:\w*:\w+/)

        data = line.split(':')

        group = data[0]
        gid   = data[2]

        # this works in some cases, deep functionality picks up the others
        users = data[3].nil? ? ['NONE'] : data[3].split(',')

        if res.has_key?(group)
          @logger.debug(sprintf('for[%s] old GID[%s] new GID[%s]', group, gid, res[group][:users])) unless gid.eql?(res[group][:gid])
          @logger.debug(sprintf('for[%s] old users[%s] new users[%s]', group, users)) unless users.eql?(res[group][:users])
        end

        res[group] = Hash.new() # i miss autovivification
        res[group][:gid]    = gid
        res[group][:users]  = users
        res[group][:source] = source
      end

    end

    groups = res

    if deep
      users = self.get_users(cache)

      known_valid_gids = groups.keys.map { |g| groups[g][:gid] } # no need to calculate this in every loop

      # TODO better, much better -- since the number of users/groups is finite and usually small, this is a low priority
      users.each_key do |user|
        # iterate over each user to get their gid
        gid = users[user][:gid]

        unless known_valid_gids.member?(gid)
          @logger.warn(sprintf('found user[%s] with unknown GID[%s], known GIDs[%s]', user, gid, known_valid_gids))
          next
        end

        ## do this more efficiently
        groups.each_key do |group|
          # iterate over each group to find the matching gid
          if gid.eql?(groups[group][:gid])
            if groups[group][:users].eql?(['NONE'])
              groups[group][:users] = []
            end
            groups[group][:users] << user unless groups[group][:users].member?(user)
          end

        end

      end
    end

    if cache
      @logger.debug(sprintf('caching [groups] at [%s]', Time.now.asctime))
      self.deltas[:groups] = groups
      self.cache[:groups]  = Time.now.to_i
    end

    groups
  end

  ##
  # get_packages
  #
  # runs an OS appropriate command to gather list of packages, returns hash:
  # {
  #   packageN => {
  #     package => version|? # if 'deep', attempts to parse version numbers
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  # * [deep] - boolean controlling whether to attempt to parse extended information (see supported OS), defaults to true
  #
  # supported OS
  # * OSX - runs `pkgutil --pkgs` and `pkgutil --pkg-info=<package>` (if deep)
  # * RedHat - runs `rpm -qa --qf "%{n}@%{v}@%{arch}\n"` (does not support deep)
  # * Solaris - runs `pkginfo` and `pkginfo -l <package>` (if deep)
  # * Ubuntu - runs `dpkg-query -W -f='${Package}\@${Version}\@${Architecture}\n'` (does not support deep)
  #
  # raises InternalError if unsupported operating system
  def get_packages(cache=true, deep=true)
    if cache and ! self.deltas[:packages].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:packages]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [packages] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:packages]), self.cache_timeout))
        self.deltas.delete(:packages)
      else
        @logger.debug(sprintf('using cached [packages] from [%s]', self.cache[:packages]))
        return self.deltas[:packages]
      end

    end

    res = Hash.new()

    os = self.os_type

    if os.eql?(:osx)

      raw = self.run('pkgutil --pkgs')
      raw.split("\n").each do |line|
        name    = line
        arch    = '?'
        version = '?'

        if deep
          # can get install time, volume and location as well
          local_res = self.run(sprintf('pkgutil --pkg-info=%s', name))
          version   = $1 if local_res.match(/version\:\s+(.*?)$/)
        end

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    elsif os.eql?(:solaris)
      raw = self.run('pkginfo')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\s+(.*?)\s(.*)$/).nil?
        name    = $2
        arch    = '?'
        version = '?'

        if deep
          begin
            # who throws non-0 exit codes when querying for legit package information? solaris does.
            local_res = self.run(sprintf('pkginfo -l %s', name))
            arch      = $1 if local_res.match(/ARCH\:\s+(.*?)$/)
            version   = $1 if local_res.match(/VERSION\:\s+(.*?)$/)
          rescue
            arch    = '?' if arch.nil?
            version = '?' if arch.nil?
          end
        end

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end
      end

    elsif os.eql?(:ubuntu) or os.eql?(:debian)
      raw = self.run("dpkg-query -W -f='${Package}@${Version}@${Architecture}\n'")
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\@(.*?)\@(.*)/).nil?
        name    = $1
        version = $2
        arch    = $3

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    elsif os.eql?(:rhel)
      raw = self.run('rpm -qa --qf "%{n}@%{v}@%{arch}\n"')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\@(.*?)\@(.*)/).nil?
        name    = $1
        version = $2
        arch    = $3

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    else
      raise InternalError.new(sprintf('VM operating system[%s] not currently supported', os))
    end

    if cache
      @logger.debug(sprintf('caching [packages] at [%s]', Time.now.asctime))
      self.deltas[:packages] = res
      self.cache[:packages]  = Time.now.to_i
    end

    res
  end

  ##
  # get_ports
  #
  # runs an OS appropriate command to gather port information, returns hash:
  # {
  #   protocolN => {
  #     portN => {
  #       :addressN => state
  #     }
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  #
  # supported OS
  # * RedHat, Ubuntu - runs `netstat -ln`
  #
  # raises InternalError if unsupported operating system
  def get_ports(cache=false)
    # TODO add unix domain sockets
    # TODO improve ipv6 support

    if cache and ! self.deltas[:ports].nil?
      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:ports]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [ports] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:ports]), self.cache_timeout))
        self.deltas.delete(:ports)
      else
        @logger.debug(sprintf('using cached [ports] from [%s]', self.cache[:ports]))
        return self.deltas[:ports]
      end
    end

    res = Hash.new()
    os  = self.os_type()

    if os.eql?(:rhel) or os.eql?(:ubuntu) or os.eql?(:debian)

      raw = self.run('netstat -ln')

      raw.split("\n").each do |line|

        next unless line.match(/(\w+)\s+\d+\s+\d+\s+([\S\:]*)\:(\w*)\s.*?(\w+)\s/) or line.match(/(\w+)\s+\d+\s+\d+\s+([\S\:]*)\:(\w*)\s.*?(\w*)\s/)

        protocol = $1
        address  = $2
        port     = $3
        state    = protocol.eql?('udp') ? 'you_might_not_get_it' : $4

        res[protocol] = Hash.new if res[protocol].nil?
        res[protocol][port] = Hash.new if res[protocol][port].nil?
        res[protocol][port][:address] = Hash.new if res[protocol][port][:address].nil?
        res[protocol][port][:address][address] = state

      end
    else
      raise InternalError.new(sprintf('unable to get port information from VM operating system[%s]', os))
    end

    if cache
      @logger.debug(sprintf('caching [ports] at [%s]', Time.now.asctime))
      self.deltas[:ports] = res
      self.cache[:ports]  = Time.now.to_i
    end

    res
  end

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
              elsif line.match(/^(\w+?)\s.*?\s(.*)$/)
                # netconsole module not loaded
                state = $2
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

  ##
  # get_users
  #
  # cats /etc/passwd and parses output, returns hash:
  # {
  #   userN => {
  #     :gid => gid,
  #     :home  => path_of_homedir,
  #     :home_exists => boolean_of_is_dir?(:home),
  #     :shell => path_to_shell,
  #     :uid => uid
  #   }
  # }
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  def get_users(cache=true)
    if cache and ! self.deltas[:users].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:users]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [users] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:users]), self.cache_timeout))
        self.deltas.delete(:users)
      else
        @logger.debug(sprintf('using cached [users] from [%s]', self.cache[:users]))
        return self.deltas[:users]
      end

    end

    res = Hash.new()

    {
      :file    => self.run('cat /etc/passwd'),
      :dynamic => self.run('getent passwd', [0,127]),
    }.each do |source, raw|

      raw.split("\n").each do |line|
        next if line.match(/([\w\.-]+)(?::\w+){3,}/).nil?

        user = $1
        data = line.split(':')

        shell       = data[-1]
        home        = data[-2]
        home_exists = self.is_dir?(data[-2])
        uid         = data[2]
        gid         = data[3]

        if res.has_key?(user)
          @logger.info(sprintf('for[%s] old shell[%s], new shell[%s]', user, res[user][:shell], shell)) unless shell.eql?(res[user][:shell])
          @logger.info(sprintf('for[%s] old home[%s], new home[%s]', user, res[user][:home], home)) unless home.eql?(res[user][:home])
          @logger.info(sprintf('for[%s] old home_exists[%s], new home_exists[%s]', user, res[user][:home_exists], home_exists)) unless home_exists.eql?(res[user][:home_exists])
          @logger.info(sprintf('for[%s] old UID[%s], new UID[%s]', user, res[user][:uid], uid)) unless uid.eql?(res[user][:uid])
          @logger.info(sprintf('for[%s] old GID[%s], new GID[%s]', user, res[user][:gid], gid)) unless gid.eql?(res[user][:gid])
        end

        res[user] = Hash.new()
        res[user][:shell]       = shell
        res[user][:home]        = home
        res[user][:home_exists] = home_exists
        res[user][:uid]         = uid
        res[user][:gid]         = gid
        res[user][:source]      = source
      end
    end

    if cache
      @logger.debug(sprintf('caching [users] at [%s]', Time.now.asctime))
      self.deltas[:users] = res
      self.cache[:users]  = Time.now.to_i
    end

    res
  end

end
