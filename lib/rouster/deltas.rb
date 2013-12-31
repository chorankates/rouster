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
        next if line.match(/^#/)
        elements = line.split("\s")

        command = elements[5..elements.size].join(' ')

        res[u] ||= Hash.new
        res[u][command] ||= Hash.new

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

    raw = self.run('cat /etc/group')

    raw.split("\n").each do |line|
      next unless line.match(/\w+:\w+:\w+/)

      data = line.split(':')

      group = data[0]
      gid   = data[2]

      # this works in some cases, deep functionality picks up the others
      users = data[3].nil? ? ['NONE'] : data[3].split(',')

      res[group] = Hash.new() # i miss autovivification
      res[group][:gid]   = gid
      res[group][:users] = users
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
  # * RedHat - runs `rpm -qa`
  # * Solaris - runs `pkginfo` and `pkginfo -l <package>` (if deep)
  # * Ubuntu - runs `dpkg --get-selections` and `dpkg -s <package>` (if deep)
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
        version = '?'

        if deep
          # can get install time, volume and location as well
          local_res = self.run(sprintf('pkgutil --pkg-info=%s', line))
          version = $1 if local_res.match(/version\:\s+(.*?)$/)
        end

        res[line] = version
      end

    elsif os.eql?(:solaris)
      raw = self.run('pkginfo')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\s+(.*?)\s(.*)$/).empty?
        name    = $2
        version = '?'

        if deep
          local_res = self.run(sprintf('pkginfo -l %s', name))
          version   = $1 if local_res.match(/VERSION\:\s+(.*?)$/i)
        end

        res[name] = version
      end

    elsif os.eql?(:ubuntu) or os.eql?(:debian)
      raw = self.run('dpkg --get-selections')
      raw.split("\n").each do |line|
        next if line.match(/^(.*?)\s/).nil?
        name    = $1
        version = '?'

        if deep
          local_res = self.run(sprintf('dpkg -s %s', name))
          version   = $1 if local_res.match(/Version\:\s(.*?)$/)
        end

        res[name] = version
      end

    elsif os.eql?(:redhat)
      raw = self.run('rpm -qa')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)-(\d*\..*)/).nil? # ht petersen.allen
        #next if line.match(/(.*)-(\d+\.\d+.*)/).nil? # another alternate, but still not perfect
        name    = $1
        version = '?' # we could use $2, but we don't trust it

        if deep
          local_res = self.run(sprintf('rpm -qi %s', line))
          name    = $1 if local_res.match(/Name\s+:\s(\S*)/)
          version = $1 if local_res.match(/Version\s+:\s(\S*)/)
        end

        res[name] = version
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

    if os.eql?(:redhat) or os.eql?(:ubuntu) or os.eql?(:debian)

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
  #
  # supported OS
  # * OSX - runs `launchctl list`
  # * RedHat - runs `/sbin/service --status-all`
  # * Solaris - runs `svcs`
  # * Ubuntu - runs `service --status-all`
  #
  # notes
  # * raises InternalError if unsupported operating system
  # * OSX, Solaris and Ubuntu/Debian will only return running|stopped|unsure, the exists|installed|operational modes are RHEL/CentOS only
  def get_services(cache=true, humanize=true)
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

    allowed_modes = %w(exists installed operational running stopped unsure)
    failover_mode = 'unsure'

    if os.eql?(:osx)

      raw = self.run('launchctl list')
      raw.split("\n").each do |line|
        next if line.match(/(?:\S*?)\s+(\S*?)\s+(\S*)$/).nil?

        service = $2
        mode    = $1

        if humanize # should we do this with a .freeze instead?
          if mode.match(/^\d/)
            mode = 'running'
          else
            mode = 'stopped'
          end
        end

        res[service] = mode
      end

    elsif os.eql?(:solaris)

      raw = self.run('svcs -a')
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

      raw = self.run('service --status-all 2>&1')
      raw.split("\n").each do |line|
        next if line.match(/\[(.*?)\]\s+(.*)$/).nil?
        mode    = $1
        service = $2

        if humanize
          mode = 'stopped' if mode.match('-')
          mode = 'running' if mode.match('\+')
          mode = 'unsure'  if mode.match('\?')
        end

        res[service] = mode
      end

    elsif os.eql?(:redhat)

      raw = self.run('/sbin/service --status-all')
      raw.split("\n").each do |line|

        if humanize

          if line.match(/^(\w+?)\sis\s(.*)$/)
            # <service> is <state>
            res[$1] = $2

            if $2.match(/^not/)
              # this catches 'Kdump is not operational'
              res[$1] = 'stopped'
            end

          elsif line.match(/^(\w+?)\s\(pid.*?\)\sis\s(\w+)$/)
            # <service> (pid <pid> [pid]) is <state>...
            res[$1] = $2
          elsif line.match(/^(\w+?)\sis\s(\w+)\.*$/) # not sure this is actually needed
            @logger.debug('triggered supposedly unnecessary regex')
            # <service> is <state>. whatever
            res[$1] = $2
          elsif line.match(/^(\w+?)\:.*?(\w+)$/)
            # <service>: whatever <state>
            res[$1] = $2
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

      end

      # issue #63 handling
      if humanize
        res.each_pair do |k,v|
          next if allowed_modes.member?(v)
          @logger.debug(sprintf('replacing service[%s] status of [%s] with [%s] for uniformity', k, v, failover_mode))
          res[k] = failover_mode
        end
      end

    else
      raise InternalError.new(sprintf('unable to get service information from VM operating system[%s]', os))
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

    raw = self.run('cat /etc/passwd')

    raw.split("\n").each do |line|
      next if line.match(/(\w+)(?::\w+){3,}/).nil?

      user = $1
      data = line.split(':')

      res[user] = Hash.new()
      res[user][:shell] = data[-1]
      res[user][:home]  = data[-2]
      res[user][:home_exists] = self.is_dir?(data[-2])
      res[user][:uid]   = data[2]
      res[user][:gid]   = data[3]
    end

    if cache
      @logger.debug(sprintf('caching [users] at [%s]', Time.now.asctime))
      self.deltas[:users] = res
      self.cache[:users]  = Time.now.to_i
    end

    res
  end

end
