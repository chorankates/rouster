require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# deltas.rb - get information about groups, packages, services and users inside a Vagrant VM

class Rouster
  # deltas.rb reimplementation
  def get_groups(use_cache=true)
    if use_cache and ! self.deltas[:groups].nil?
      self.deltas[:groups]
    end

    res = Hash.new()

    raw = self.run('cat /etc/group')

    raw.split("\n").each do |line|
      next if line.grep(/\w+:\w+:\w+/).empty?

      data = line.split(':')

      group = data[0]
      gid   = data[2]
      users = data[3].nil? ? ['NONE'] : data[3].split(',')

      res[group] = Hash.new() # i miss autovivification
      res[group][:gid]   = gid
      res[group][:users] = users
    end

    if use_cache
      self.deltas[:groups] = res
    end

    res
  end

  def get_packages(use_cache=true, deep=true)
    # returns { package => '<version>', package2 => '<version>' }

    if use_cache and ! self.deltas[:packages].nil?
      self.deltas[:packages]
    end

    res = Hash.new()

    os = self.os_type

    if os.eql?(:osx)

      raw = self.run('pkgutil --pkgs')
      raw.split("\n").each do |line|

        if deep
          # can get install time, volume and location as well
          local_res = self.run(sprintf('pkgutil --pkg-info=%s', line))
          local     = $1 if local_res.match(/version\:\s+(.*?)$/)
        else
          local = '?'
        end

        res[line] = local
      end

    elsif os.eql?(:solaris)
      raw = self.run('pkginfo')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\s+(.*?)\s(.*)$/).empty?

        if deep
          local_res = self.run(sprintf('pkginfo -l %s', $2))
          local     = $1 if local_res.match(/VERSION\:\s+(.*?)$/i)
        else
          local = '?'
        end

        res[$2] = local
      end

    elsif os.eql?(:ubuntu)
      raw = self.run('dpkg --get-selections')
      raw.split("\n").each do |line|
        next if line.match(/^(.*?)\s/).nil?

        if deep
          local_res = self.run(sprintf('dpkg -s %s', $1))
          local     = $1 if local_res.match(/Version\:\s(.*?)$/)
        else
          local = '?'
        end

        res[$1] = local
      end

    elsif os.eql?(:redhat)
      raw = self.run('rpm -qa')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)-(\d*\..*)/).nil? # ht petersen.allen
        res[$1] = $2
      end

    else
      raise InternalError.new(sprintf('unable to determine VM operating system from[%s]', uname))
    end

    if use_cache
      self.deltas[:packages] = res
    end

    res
  end

  def get_services(use_cache=true)
    if use_cache and ! self.deltas[:services].nil?
      self.deltas[:services]
    end

    res = Hash.new()

    os = self.os_type

    if os.eql?(:osx)

      raw = self.run('launchctl list')
      raw.split("\n").each do |line|
        next if line.match(/(?:\S*?)\s+(\S*?)\s+(\S*)$/).nil?

        service = $2
        mode    = $1

        if mode.grep(/^\d/)
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

    elsif os.eql?(:ubuntu)

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
        #next if line.grep(/([\w\s-]+?)\sis\s(\w*?)/).empty?
        next if line.match(/^([^\s]*).*\s(\w*)\.?$/).nil?
        res[$1] = $2
      end

    else
      raise InternalError.new(sprintf('unable to determine VM operating system from[%s]', uname))
    end

    if use_cache
      self.deltas[:services] = res
    end

    res
  end

  def get_users(use_cache=true)
    if use_cache and ! self.deltas[:users].nil?
      self.deltas[:users]
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

    if use_cache
      self.deltas[:users] = res
    end

    res
  end

end