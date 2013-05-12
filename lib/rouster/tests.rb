require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

class Rouster

  def is_dir?(dir)
    begin
      res = self.run(sprintf('ls -ld %s', dir))
    rescue RemoteExecutionError
      # noop, process output instead of exit code
    end

    if res.nil?
      # TODO resolve this issue - need to get run() to return STDERR when a non-0 exit code is returned
      false
    elsif res.match(/No such file or directory/)
      false
    elsif res.match(/Permission denied/)
      self.log.info(sprintf('is_dir?(%s) output[%s], try with sudo', dir, res)) unless self.uses_sudo?
      false
    else
      #true
      parse_ls_string(res)
    end
  end

  def is_executable?(filename, level='u')

    res = is_file?(filename)

    if res
      array = res[:executable?]

      case level
        when 'u', 'U', 'user'
          array[0]
        when 'g', 'G', 'group'
          array[1]
        when 'o', 'O', 'other'
          array[2]
        else
          raise InternalError.new(sprintf('unknown level[%s]'))
      end

    else
      false
    end

  end

  def is_file?(file)
    begin
      res = self.run(sprintf('ls -l %s', file))
    rescue RemoteExecutionError
      # noop, process output
    end

    if res.nil?
      # TODO remove this when run() can return STDERR on non-0 exit codes
      false
    elsif res.match(/No such file or directory/)
      self.log.info(sprintf('is_file?(%s) output[%s], try with sudo', file, res)) unless self.uses_sudo?
      false
    elsif res.match(/Permission denied/)
      false
    else
      #true
      parse_ls_string(res)
    end

  end

  def is_group?(group)
    groups = self.get_groups()
    groups.has_key?(group)
  end

  def is_in_file?(file, regex, scp=false)

    res = nil

    if scp
      # download the file to a temporary directory
      # not implementing as part of MVP
    end

    begin
      command = sprintf("grep -c '%s' %s", regex, file)
      res     = self.run(command)
    rescue RemoteExecutionError
      false
    end

    if res.grep(/^0/)
      false
    else
      true
    end

  end

  def is_in_path?(filename)
    begin
      self.run(sprintf('which %s', filename))
    rescue RemoteExecutionError
      false
    end

    true
  end

  def is_package?(package)
    packages = self.get_packages()
    packages.has_key?(package)
  end

  def is_readable?(filename, level='u')

    res = is_file?(filename)

    if res
      array = res[:readable?]

      case level
        when 'u', 'U', 'user'
          array[0]
        when 'g', 'G', 'group'
          array[1]
        when 'o', 'O', 'other'
          array[2]
        else
          raise InternalError.new(sprintf('unknown level[%s]'))
      end

    else
      false
    end

  end

  def is_service?(service)
    services = self.get_services()
    services.has_key?(service)
  end

  def is_service_running?(service)
    services = self.get_services()

    if services.has_key?(service)
      services[service].grep(/running|enabled|started/)
    end
  end

  def is_user?(user)
    users = self.get_users()
    users.has_key?(user)
  end

  def is_writeable?(filename, level='u')

    res = is_file?(filename)

    if res
      array = res[:writeable?]

      case level
        when 'u', 'U', 'user'
          array[0]
        when 'g', 'G', 'group'
          array[1]
        when 'o', 'O', 'other'
          array[2]
        else
          raise InternalError.new(sprintf('unknown level[%s]'))
      end

    else
      false
    end

  end

  # non-test, helper methods
  def parse_ls_string(string)

    res = Hash.new()

    tokens = string.split(/\s+/)

    # eww
    modes = [ tokens[0][1..3], tokens[0][4..6], tokens[0][7..9] ]
    mode  = 0

    # can't use modes.size here (or could, but would have to -1)
    for i in 0..2 do
      value   = 0
      element = modes[i]

      for j in 0..2 do
        chr = element[j].chr
        case chr
          when 'r'
            value += 4
          when 'w'
            value += 2
          when 'x', 't'
            # is 't' really right here? copying Salesforce::piab
            value += 1
          when '-'
            # noop
          else
            raise InternalError.new(sprintf('unexpected character[%s]', chr))
        end

      end

      mode = sprintf('%s%s', mode, value)
    end

    res[:mode]  = mode
    res[:owner] = tokens[2]
    res[:group] = tokens[3]
    res[:size]  = tokens[4]

    # TODO you are smarter than this. build some tests and then rewrite this with confidence
    res[:directory?]  = tokens[0][0].chr.eql?('d')
    res[:executable?] = [ tokens[0][3].chr.eql?('x'), tokens[0][6].chr.eql?('x'), tokens[0][9].chr.eql?('x') || tokens[0][9].chr.eql?('t') ]
    res[:readable?]   = [ tokens[0][2].chr.eql?('w'), tokens[0][5].chr.eql?('w'), tokens[0][8].chr.eql?('w') ]
    res[:writeable?]  = [ tokens[0][1].chr.eql?('r'), tokens[0][4].chr.eql?('r'), tokens[0][7].chr.eql?('r') ]

    res
  end

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
      res[group]['gid']   = gid
      res[group]['users'] = users
    end

    if use_cache
      self.deltas[:groups] = res
    end

    res
  end

  def get_packages(use_cache=true)
    if use_cache and ! self.deltas[:packages].nil?
      self.deltas[:packages]
    end

    res = Hash.new()

    # TODO ask Vagrant for this information
    uname = self.run('uname -a')

    if uname =~ /darwin/

      raw = self.run('pkgutil --pkgs')
      raw.split("\n").each do |line|
        # can get actual version with 'pkgutil --pkg-info=#{line}', but do we really want to? is there a better way?
        res[line] = '?'
      end

    elsif uname =~ /SunOS/

      raw = self.run('pkginfo')
      raw.split("\n").each do |line|
        # can get actual version with 'pkginfo -c #{package}', but do we really want to?
        next if line.grep(/(.*?)\s+(.*?)\s(.*)$/).empty?

        category = $1
        package  = $2
        name     = $3

        res[category] = Hash.new() if res[category].nil?
        res[category][package] = name

        end

    elsif uname =~ /Ubuntu/

      raw = self.run('dpkg --get-selections')
      raw.split("\n").each do |line|
        # can get actual version with 'dpkg -s #{package}'
        next if line.grep(/^(.*?)\s/).empty?

        res[package] = '?'
      end

    elsif self.is_file?('/etc/redhat-release')

      raw = self.run('rpm -qa')
      raw.split("\n").each do |line|
        next if line.grep(/(.*?)-(\d*\..*)/).empty? # ht petersen.allen
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

  def get_users(use_cache=true)
    if use_cache and ! self.deltas[:users].nil?
      self.deltas[:users]
    end

    res = Hash.new()

    raw = self.run('cat /etc/passwd')

    raw.split("\n").each do |line|
      next if line.grep(/(\w+)(?::\w+){3,}/).empty?

      user = $1
      data = line.split(":")

      res[user] = Hash.new()
      res[user]['shell'] = data[-1]
      res[user]['home']  = data[-2]
      #res[user]['home_exists'] = self.is_directory?(data[-2]) # do we really want this?
      res[user]['uid']   = data[2]
    end

    if use_cache
      self.deltas[:users] = res
    end

    res
  end

  def get_services(use_cache=true)
    if use_cache and ! self.deltas[:services].nil?
      self.deltas[:services]
    end

    res = Hash.new()

    # TODO ask Vagrant for this information
    uname = self.run('uname -a')

    if uname =~ /darwin/

      raw = self.run('launchctl') # TODO is this really what we're looking for?
      raw.split("\n").each do |line|
        next if line.grep(/(?:\S*?)\s+(\S*?)\s+(\S*)$/).empty

        service = $2
        mode    = $1 # this is either '-', '0', or '-9'

        res[service] = mode
      end

    elsif uname =~ /SunOS/

      raw = self.run('svcs') # TODO ensure that this is giving all services, not just those that are started
      raw.split("\n").each do |line|
        next if line.grep(/(.*?)\s+(?:.*?)\s+(.*?)$/).empty?

        service = $2
        mode    = $1

        res[service] = mode

      end

    elsif uname =~ /Ubuntu/

      raw = self.run('service --status-all 2>&1')
      raw.split("\n").each do |line|
        next if line.grep(/\[(.*?)\]\s+(.*)$/).empty?
        mode    = $1
        service = $2

        mode = 'stopped' if mode.match('-')
        mode = 'running' if mode.match('\+')
        mode = 'unsure'  if mode.match('\?')

        res[service] = mode
      end

    elsif self.is_file?('/etc/redhat-release')

      raw = self.run('/sbin/service --status-all')
      raw.split("\n").each do |line|
        #next if line.grep(/([\w\s-]+?)\sis\s(\w*?)/).empty?
        next if line.grep(/^([^\s]*).*\s(\w*)\.?$/).empty?
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

end
