require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/deltas'

class Rouster

  ##
  # dir
  #
  # runs `ls -ld <dir>` and parses output, returns nil (if dir DNE or permission issue) or hash:
  # {
  #   :directory? => boolean,
  #   :file? => boolean,
  #   :executable? => boolean, # based on user 'vagrant' context
  #   :writeable? => boolean, # based on user 'vagrant' context
  #   :readable? => boolean, # based on user 'vagrant' context
  #   :mode => mode, # 0-prefixed octal mode
  #   :name => name, # short name
  #   :owner => owner,
  #   :group => group,
  #   :size => size, # in bytes
  # }
  #
  # parameters
  # * <dir> - path of directory to act on, full path or relative to ~vagrant/
  # * [cache] - boolean controlling whether to cache retrieved data, defaults to false
  def dir(dir, cache=false)

    if cache and self.deltas[:files].class.eql?(Hash) and ! self.deltas[:files][dir].nil?
      return self.deltas[:files][dir]
    end

    if self.unittest and cache
      # preventing a functional test fallthrough
      return nil
    end

    begin
      raw  = self.run(sprintf('ls -ld %s', dir)).to_s
      raw += self.get_ssh_stderr().to_s
    rescue Rouster::RemoteExecutionError
      raw = self.get_ssh_stdout().to_s + self.get_ssh_stderr().to_s
    end

    if raw.match(/No such file or directory/)
      res = nil
    elsif raw.match(/Permission denied/)
      @logger.info(sprintf('dir(%s) output[%s], try with sudo', dir, raw)) unless self.uses_sudo?
      res = nil
    else
      res = parse_ls_string(raw)
    end

    if cache
      self.deltas[:files] = Hash.new if self.deltas[:files].nil?
      self.deltas[:files][dir] = res
    end

    res
  end

  ##
  # dirs
  #
  # runs `find <dir> <recursive muckery> -type d -name '<wildcard>'`, and returns array of directories (fully qualified paths)
  #
  # parameters
  # * <dir> - path to directory to act on, full path or relative to ~vagrant/
  # * [wildcard] - glob of directories to match, defaults to '*'
  # * [recursive] - boolean controlling whether or not to look in directories recursively, defaults to false
  def dirs(dir, wildcard='*', insensitive=true, recursive=false)
    # TODO use a numerical, not boolean value for 'recursive' -- and rename to 'depth' ?
    raise InternalError.new(sprintf('invalid dir specified[%s]', dir)) unless self.is_dir?(dir)

    raw = self.run(sprintf("find %s %s -type d %s '%s'", dir, recursive ? '' : '-maxdepth 1', insensitive ? '-iname' : '-name', wildcard))
    res = Array.new

    raw.split("\n").each do |line|
      next if line.eql?(dir)
      res.push(line)
    end

    res
  end

  ##
  # file
  #
  # runs `ls -l <file>` and parses output, returns nil (if file DNE or permission issue) or hash:
  # {
  #   :directory? => boolean,
  #   :file? => boolean,
  #   :executable? => boolean, # based on user 'vagrant' context
  #   :writeable? => boolean, # based on user 'vagrant' context
  #   :readable? => boolean, # based on user 'vagrant' context
  #   :mode => mode, # 0-prefixed octal mode
  #   :name => name, # short name
  #   :owner => owner,
  #   :group => group,
  #   :size => size, # in bytes
  # }
  #
  # parameters
  # * <file> - path of file to act on, full path or relative to ~vagrant/
  # * [cache] - boolean controlling whether to cache retrieved data, defaults to false
  def file(file, cache=false)

    if cache and self.deltas[:files].class.eql?(Hash) and ! self.deltas[:files][file].nil?
      return self.deltas[:files][file]
    end

    if self.unittest and cache
      # preventing a functional test fallthrough
      return nil
    end

    begin
      raw = self.run(sprintf('ls -l %s', file))
    rescue Rouster::RemoteExecutionError
      raw = self.get_ssh_stdout()
    end

    if raw.match(/No such file or directory/)
      @logger.info(sprintf('is_file?(%s) output[%s], try with sudo', file, raw)) unless self.uses_sudo?
      res = nil
    elsif raw.match(/Permission denied/)
      res = nil
    else
      res = parse_ls_string(raw)
    end

    if cache
      self.deltas[:files] = Hash.new if self.deltas[:files].nil?
      self.deltas[:files][file] = res
    end

    res
  end

  ##
  # files
  #
  # runs `find <dir> <recursive muckery> -type f -name '<wildcard>'`, and reutns array of files (fullly qualified paths)
  # parameters
  # * <dir> - directory to look in, full path or relative to ~vagrant/
  # * [wildcard] - glob of files to match, defaults to '*'
  # * [recursive] - boolean controlling whether or not to look in directories recursively, defaults to false
  def files(dir, wildcard='*', insensitive=true, recursive=false)
    # TODO use a numerical, not boolean value for 'recursive'
    raise InternalError.new(sprintf('invalid dir specified[%s]', dir)) unless self.is_dir?(dir)

    raw = self.run(sprintf("find %s %s -type f %s '%s'", dir, recursive ? '' : '-maxdepth 1', insensitive ? '-iname' : '-name', wildcard))
    res = Array.new

    raw.split("\n").each do |line|
      res.push(line)
    end

    res
  end

  ##
  # is_dir?
  #
  # uses dir() to return boolean indicating whether parameter passed is a directory
  #
  # parameters
  # * <dir> - path of directory to validate
  def is_dir?(dir)
    res = nil
    begin
      res = self.dir(dir)
    rescue => e
      return false
    end

    res.class.eql?(Hash) ? res[:directory?] : false
  end

  ##
  # is_executable?
  #
  # uses file() to return boolean indicating whether parameter passed is an executable file
  #
  # parameters
  # * <filename> - path of filename to validate
  # * [level] - string indicating 'u'ser, 'g'roup or 'o'ther context, defaults to 'u'
  def is_executable?(filename, level='u')
    res = nil

    begin
      res = file(filename)
    rescue Rouster::InternalError
      res = dir(filename)
    end

    # for cases that are directories, but don't throw exceptions
    if res.nil? or res[:directory?]
      res = dir(filename)
    end

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

  ##
  # is_file?
  #
  # uses file() to return boolean indicating whether parameter passed is a file
  #
  # parameters
  # * <file> - path of filename to validate
  def is_file?(file)
    res = nil

    begin
      res = self.file(file)
    rescue => e
      return false
    end

    res.class.eql?(Hash) ? res[:file?] : false
  end

  ##
  # is_group?
  #
  # uses get_groups() to return boolean indicating whether parameter passed is a group
  #
  # parameters
  # * <group> - name of group to validate
  def is_group?(group)
    groups = self.get_groups()
    groups.has_key?(group)
  end

  ##
  # is_in_file?
  #
  # calls `grep -c '<regex>' <file>` and returns boolean for whether one or more matches are found in file
  #
  # parameters
  # * <file> - path of filename to examine
  # * <regex> - regular expression/string to be passed to grep
  # * <flags> - flags to include in grep command
  # * [scp] - downloads file to host machine before grepping (functionality not implemented, was planned when a new SSH connection was required for each run() command, not sure it is necessary any longer)
  def is_in_file?(file, regex, flags='', scp=false)

    res = nil

    if scp
      # download the file to a temporary directory
      @logger.warn('is_in_file? scp option not implemented yet')
    end

    begin
      command = sprintf("grep -c%s '%s' %s", flags, regex, file)
      res     = self.run(command)
    rescue Rouster::RemoteExecutionError
      return false
    end

    if res.nil?.false? and res.match(/^0/)
      false
    else
      true
    end

  end

  ##
  # is_in_path?
  #
  # runs `which <filename>`, returns boolean of whether the filename is exectuable and in $PATH
  #
  # parameters
  # * <filename> - name of executable to validate
  def is_in_path?(filename)
    begin
      self.run(sprintf('which %s', filename))
    rescue Rouster::RemoteExecutionError
      return false
    end

    true
  end

  ##
  # is_package?
  #
  # uses get_packages() to return boolean indicating whether passed parameter is an installed package
  #
  # parameters
  # * <package> - name of package to validate
  # * [cache] - boolean controlling whether to cache results from get_packages(), defaults to true (for performance)
  def is_package?(package, cache=true)
    # TODO should we implement something like is_package_version?()
    packages = self.get_packages(cache)
    packages.has_key?(package)
  end

  ##
  # is_port_active?
  #
  # uses get_ports() to return boolean indicating whether passed port is in use
  #
  # parameters
  # * <port> - port number to validate
  # * [proto] - specification of protocol to examine, defaults to tcp
  # * [cache] - boolean controlling whether to cache get_ports() data, defaults to false
  def is_port_active?(port, proto='tcp', cache=false)
    # TODO is this the right name?
    ports = self.get_ports(cache)
    port  = port.to_s
    if ports[proto].class.eql?(Hash) and ports[proto].has_key?(port)

      if proto.eql?('tcp')
        ['ACTIVE', 'ESTABLISHED', 'LISTEN']. each do |allowed|
          return true if ports[proto][port][:address].values.member?(allowed)
        end
      else
        return true
      end

    end

    false
  end

  ##
  # is_port_open?
  #
  # uses get_ports() to return boolean indicating whether passed port is open
  #
  # parameters
  # * <port> - port number to validate
  # * [proto] - specification of protocol to examine, defaults to tcp
  # * [cache] - boolean controlling whether to cache get_ports() data, defaults to false
  def is_port_open?(port, proto='tcp', cache=false)
    ports = self.get_ports(cache)
    port  = port.to_s
    if ports[proto].class.eql?(Hash) and ports[proto].has_key?(port)
      return false
    end

    true
  end

  ##
  # is_process_running?
  #
  # runs `ps ax | grep -c <process>` looking for more than 2 results
  #
  # parameters
  # * <name> - name of process to look for
  #
  # supported OS
  # * OSX
  # * RedHat
  # * Ubuntu
  def is_process_running?(name)
    # TODO support Solaris
    # TODO do better validation than just grepping for a matching filename, start with removing 'grep' from output
    begin

      os = self.os_type()

      case os
        when :rhel, :osx, :ubuntu, :debian
          res = self.run(sprintf('ps ax | grep -c %s', name))
        else
          raise InternalError.new(sprintf('currently unable to determine running process list on OS[%s]', os))
      end

    rescue Rouster::RemoteExecutionError
      return false
    end

    res.chomp.to_i > 2 # because of the weird way our process is run through the ssh tunnel
  end

  ##
  # is_readable?
  #
  # uses file() to return boolean indicating whether parameter passed is an readable file
  #
  # parameters
  # * <filename> - path of filename to validate
  # * [level] - string indicating 'u'ser, 'g'roup or 'o'ther context, defaults to 'u'
  def is_readable?(filename, level='u')
    res = nil

    begin
      res = file(filename)
    rescue Rouster::InternalError
      res = dir(filename)
    end

    # for cases that are directories, but don't throw exceptions
    if res.nil? or res[:directory?]
      res = dir(filename)
    end

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

  ##
  # is_service?
  #
  # uses get_services() to return boolean indicating whether passed parameter is an installed service
  #
  # parameters
  # * <service> - name of service to validate
  # * [cache] - boolean controlling whether to cache results from get_services(), defaults to true
  def is_service?(service, cache=true)
    services = self.get_services(cache)
    services.has_key?(service)
  end


  ##
  # is_service_running?
  #
  # uses get_services() to return boolean indicating whether passed parameter is a running service
  #
  # parameters
  # * <service> - name of service to validate
  # * [cache] - boolean controlling whether to cache results from get_services(), defaults to false
  def is_service_running?(service, cache=false)
    services = self.get_services(cache)

    if services.has_key?(service)
      services[service].eql?('running').true?
    else
      false
    end
  end

  ##
  # is_symlink?
  #
  # uses file() to return boolean indicating whether parameter passed is a symlink
  #
  # parameters
  # * <file> - path of filename to validate
  def is_symlink?(file)
    res = nil

    begin
      res = self.file(file)
    rescue => e
      return false
    end

    res.class.eql?(Hash) ? res[:symlink?] : false
  end

  ##
  # is_user?
  #
  # uses get_users() to return boolean indicating whether passed parameter is a user
  #
  # parameters
  # * <user> - username to validate
  # * [cache] - boolean controlling whether to cache results from get_users(), defaults to true
  def is_user?(user, cache=true)
    users = self.get_users(cache)
    users.has_key?(user)
  end

  ##
  # is_user_in_group?
  #
  # uses get_users() and get_groups() to return boolean indicating whether passed user is in passed group
  #
  # parameters
  # * <user> - username to validate
  # * <group> - group expected to contain user
  # * [cache] - boolean controlling whether to cache results from get_users() and get_groups(), defaults to true
  def is_user_in_group?(user, group, cache=true)
    # TODO can we scope this down to just use get_groups?
    users  = self.get_users(cache)
    groups = self.get_groups(cache)

    users.has_key?(user) and groups.has_key?(group) and groups[group][:users].member?(user)
  end

  ##
  # is_writeable?
  #
  # uses file() to return boolean indicating whether parameter passed is an executable file
  #
  # parameters
  # * <filename> - path of filename to validate
  # * [level] - string indicating 'u'ser, 'g'roup or 'o'ther context, defaults to 'u'
  def is_writeable?(filename, level='u')
    res = nil

    begin
      res = file(filename)
    rescue Rouster::InternalError
      res = dir(filename)
    end

    # for cases that are directories, but don't throw exceptions
    if res.nil? or res[:directory?]
      res = dir(filename)
    end

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
  #private
  def parse_ls_string(string)
    # ht avaghti

    res = Hash.new()

    tokens = string.split(/\s+/)

    # eww - do better here
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
          when 'x', 't', 's'
            # is 't' / 's' really right here? copying Salesforce::Vagrant
            value += 1
          when '-'
            # noop
          else
            raise InternalError.new(sprintf('unexpected character[%s] in string[%s]', chr, string))
        end

      end

      mode = sprintf('%s%s', mode, value)
    end

    res[:mode]  = mode
    res[:owner] = tokens[2]
    res[:group] = tokens[3]
    res[:size]  = tokens[4]

    res[:directory?]  = tokens[0][0].chr.eql?('d')
    res[:file?]       = ! res[:directory?]
    res[:symlink?]    = tokens[0][0].chr.eql?('l')
    res[:executable?] = [ tokens[0][3].chr.eql?('x'), tokens[0][6].chr.eql?('x'), tokens[0][9].chr.eql?('x') || tokens[0][9].chr.eql?('t') ]
    res[:writeable?]  = [ tokens[0][2].chr.eql?('w'), tokens[0][5].chr.eql?('w'), tokens[0][8].chr.eql?('w') ]
    res[:readable?]   = [ tokens[0][1].chr.eql?('r'), tokens[0][4].chr.eql?('r'), tokens[0][7].chr.eql?('r') ]

    # TODO better here: this does not support files/dirs with spaces
    if res[:symlink?]
      # not sure if we should only be adding this value if we're a symlink, or adding it to all results and just using nil if not a link
      res[:target] = tokens[-1]
      res[:name]   = tokens[-3]
    else
      res[:name] = tokens[-1]
    end

    res
  end

end
