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
      return false
    elsif res.match(/No such file or directory/)
      return false
    elsif res.match(/Permission denied/)
      self.log.info(sprintf('is_dir?(%s) output[%s], try with sudo', dir, res)) unless self.uses_sudo?
      return false
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
      return false
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
      return false
    elsif res.match(/No such file or directory/)
      self.log.info(sprintf('is_file?(%s) output[%s], try with sudo', file, res)) unless self.uses_sudo?
      return false
    elsif res.match(/Permission denied/)
      return false
    else
      #true
      parse_ls_string(res)
    end

  end

  def is_group?(group)
    raise NotImplementedError.new('this will require deltas.rb functionality')
  end

  def is_in_file?(file, regex, scp=false)

    if scp
      # download the file to a temporary directory
      # typically used if you're going to make a lot of greps against it, since we have to ssh in each time

      # although this isn't exactly true anymore, once vagrant connects once, it leaves the pipe open

      # not implementing as part of MVP

    end

    begin
      command = sprintf("grep -c '%s' %s", regex, file)
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
      res = self.run(sprintf('which %s', filename))
    rescue RemoteExecutionError
      false
    end

    true
  end

  def is_package?(package)
    raise NotImplementedError.new('this will require deltas.rb functionality')
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
    raise NotImplementedError.new('this will require deltas.rb functionality')
  end

  def is_service_running?(service)
    raise NotImplementedError.new('this will require deltas.rb functionality')
  end

  def is_user?(user)
    raise NotImplementedError.new('this will require deltas.rb functionality')
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

    #drwx------ 2 vagrant vagrant  4096 May 10 19:13 ssh-elQYXX1676
    #-rw-r--r-- 1 root    root        0 Dec  6 07:56 vagrant-ifcfg-eth1

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
  def get_groups
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

    res
  end

  def get_packages
    res = Hash.new()

    # TODO ask Vagrant for this information
    uname = self.run('uname -a')

    if uname =~ /darwin/
      raise NotImplementedError.new('no OSX support yet')
    elsif uname =~ /SunOS/
      raise NotImplementedError.new('no Solaris support yet')
    elsif uname =~ /Ubuntu/
      raise NotImplementedError.new('no Ubuntu support yet')
    elsif self.is_file?('/etc/redhat-release')

      raw = self.run('rpm -qa')
      raw.split("\n").each do |line|
        next if line.grep(/(.*?)-(\d*\..*)/).empty? # ht petersen.allen
        res[$1] = $2
      end

    else
      raise InternalError.new(sprintf('unable to determine VM operating system from[%s]', uname))
    end

    res
  end

  def get_users
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

    res
  end

  def get_services
    res = Hash.new()

    # TODO ask Vagrant for this information
    uname = self.run('uname -a')

    if uname =~ /darwin/
      raise NotImplementedError.new('no OSX support yet')
    elsif uname =~ /SunOS/
      raise NotImplementedError.new('no Solaris support yet')
    elsif uname =~ /Ubuntu/
      raise NotImplementedError.new('no Ubuntu support yet')
    elsif self.is_file?('/etc/redhat-release')

      raw = self.run('/sbin/service --status-all')
      raw.split("\n").each do |line|
        #next if line.grep(/([\w\s-]+?)\sis\s(\w*?)/).empty?
        next if line.grep(/^([^\s]*).*\s(\w*)\.?$/).empty?
        services[$1] = $2
      end

    else
      raise InternalError.new(sprintf('unable to determine VM operating system from[%s]', uname))
    end

    res
  end

end
