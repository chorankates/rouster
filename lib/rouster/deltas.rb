require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# deltas.rb - get information about groups, packages, services and users inside a Vagrant VM
require 'rouster'
require 'rouster/tests'

# TODO use @cache_timeout to invalidate data cached here

class Rouster

  ##
  # get_crontab
  #
  # runs `crontab -l <user>` and parses output, returns hash:
  # {
  #   user => {
  #     logicalOrderInt => {
  #       :minute => minute,
  #       :hour   => hour,
  #       :dom    => dom, # day of month
  #       :mon    => mon, # month
  #       :dow    => dow, # day of week
  #       :command => command,
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
      if self.deltas[:crontab].has_key?(user)
        return self.deltas[:crontab][user]
      else
        # noop fallthrough to gather data to cache
      end
    elsif cache and self.deltas[:crontab].class.eql?(Hash) and user.eql?('*')
      return self.deltas[:crontab]
    end

    i = 0
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
        elements = line.split("\s")

        res[u] ||= Hash.new
        res[u][i] ||= Hash.new

        res[u][i][:minute]  = elements[0]
        res[u][i][:hour]    = elements[1]
        res[u][i][:dom]     = elements[2]
        res[u][i][:mon]     = elements[3]
        res[u][i][:dow]     = elements[4]
        res[u][i][:command] = elements[5..elements.size].join(" ")
      end

      i += 1
    end

    if cache
      if ! user.eql?('*')
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab][user] ||= Hash.new
        self.deltas[:crontab][user] = res[user]
      else
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab] = res
      end
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
  def get_groups(cache=true)
    if cache and ! self.deltas[:groups].nil?
      return self.deltas[:groups]
    end

    res = Hash.new()

    raw = self.run('cat /etc/group')

    raw.split("\n").each do |line|
      next unless line.match(/\w+:\w+:\w+/)

      data = line.split(':')

      group = data[0]
      gid   = data[2]
      users = data[3].nil? ? ['NONE'] : data[3].split(',')

      res[group] = Hash.new() # i miss autovivification
      res[group][:gid]   = gid
      res[group][:users] = users
    end

    if cache
      self.deltas[:groups] = res
    end

    res
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
      return self.deltas[:packages]
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
        version = $2

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
      self.deltas[:packages] = res
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
      return self.deltas[:ports]
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
      self.deltas[:ports] = res
    end

    res
  end

  ##
  # get_services
  #
  # runs an OS appropriate command to gather service information, returns hash:
  # {
  #   serviceN => mode # running|stopped|unsure
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  #
  # supported OS
  # * OSX - runs `launchctl list`
  # * RedHat - runs `/sbin/service --status-all`
  # * Solaris - runs `svcs`
  # * Ubuntu - runs `service --status-all`
  #
  # raises InternalError if unsupported operating system
  def get_services(cache=true)
    if cache and ! self.deltas[:services].nil?
      return self.deltas[:services]
    end

    res = Hash.new()

    os = self.os_type

    if os.eql?(:osx)

      raw = self.run('launchctl list')
      raw.split("\n").each do |line|
        next if line.match(/(?:\S*?)\s+(\S*?)\s+(\S*)$/).nil?

        service = $2
        mode    = $1

        if mode.match(/^\d/)
          mode = 'running'
        else
          mode = 'stopped'
        end

        res[service] = mode
      end

    elsif os.eql?(:solaris)

      raw = self.run('svcs')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\s+(?:.*?)\s+(.*?)$/).nil?

        service = $2
        mode    = $1

        if mode.match(/online/)
          mode = 'running'
        elsif mode.match(/legacy_run/)
          mode = 'running'
        elsif mode.match(//)
          mode = 'stopped'
        end

        res[service] = mode

      end

    elsif os.eql?(:ubuntu) or os.eql?(:debian)

      raw = self.run('service --status-all 2>&1')
      raw.split("\n").each do |line|
        next if line.match(/\[(.*?)\]\s+(.*)$/).nil?
        mode    = $1
        service = $2

        mode = 'stopped' if mode.match('-')
        mode = 'running' if mode.match('\+')
        mode = 'unsure'  if mode.match('\?')

        res[service] = mode
      end

    elsif os.eql?(:redhat)

      raw = self.run('/sbin/service --status-all')
      raw.split("\n").each do |line|
        # TODO tighten this up
        next if line.match(/^([^\s:]*).*\s(\w*)(?:\.?){3}$/).nil?
        res[$1] = $2
      end

    else
      raise InternalError.new(sprintf('unable to get service information from VM operating system[%s]', os))
    end

    if cache
      self.deltas[:services] = res
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
      return self.deltas[:users]
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
      self.deltas[:users] = res
    end

    res
  end

end
