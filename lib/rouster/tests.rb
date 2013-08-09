require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster/deltas'

class Rouster

  def dir(dir, cache=false)

    self.deltas[:files] = Hash.new if self.deltas[:files].nil?
    if cache and ! self.deltas[:files][dir].nil?
      self.deltas[:files][dir]
    end

    begin
      raw = self.run(sprintf('ls -ld %s', dir))
    rescue Rouster::RemoteExecutionError
      raw = self.get_output()
    end

    if raw.match(/No such file or directory/)
      res = nil
    elsif raw.match(/Permission denied/)
      @log.info(sprintf('is_dir?(%s) output[%s], try with sudo', dir, raw)) unless self.uses_sudo?
      res = nil
    else
      res = parse_ls_string(raw)
    end

    if cache
      self.deltas[:files][dir] = res
    end

    res
  end

  def file(file, cache=false)

    self.deltas[:files] = Hash.new if self.deltas[:files].nil?
    if cache and ! self.deltas[:files][file].nil?
      self.deltas[:files][file]
    end

    begin
      raw = self.run(sprintf('ls -l %s', file))
    rescue Rouster::RemoteExecutionError
      raw = self.get_output()
    end

    if raw.match(/No such file or directory/)
      @log.info(sprintf('is_file?(%s) output[%s], try with sudo', file, raw)) unless self.uses_sudo?
      res = nil
    elsif raw.match(/Permission denied/)
      res = nil
    else
      res = parse_ls_string(raw)
    end

    if cache
      self.deltas[:file] = Hash.new if self.deltas[:file].nil?
      self.deltas[:files][file] = res
    end

    res
  end

  def is_dir?(dir)
    res = self.dir(dir)
    res.class.eql?(Hash) ? res[:directory?] : false
  end

  def is_executable?(filename, level='u')

    res = file(filename)

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
    res = self.file(file)
    res.class.eql?(Hash) ? res[:file?] : false
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
    rescue Rouster::RemoteExecutionError
      return false
    end

    if res.nil?.false? and res.match(/^0/)
      false
    else
      true
    end

  end

  def is_in_path?(filename)
    begin
      self.run(sprintf('which %s', filename))
    rescue Rouster::RemoteExecutionError
      return false
    end

    true
  end

  def is_package?(package, cache=true)
    packages = self.get_packages(cache)
    packages.has_key?(package)
  end

  def is_port_closed?(port, cache=false)
    ports = self.get_ports(cache)
    ports.has_key(port)
  end

  def is_port_open?(port, cache=false)
    ports = self.get_ports(cache)
    ! ports.has_key?(port)
  end

  def is_process_running?(name)
    # TODO support other flavors - this will work on RHEL and OSX
    begin

      os = self.os_type()

      case os
        when :rhel, :darwin
          res = self.run(sprintf('ps ax | grep -c %s', name))
        else
          raise InternalError.new(sprintf('currently unable to determine running process list on OS[%s]', os))
      end

    rescue Rouster::RemoteExecutionError
      return false
    end

    res.chomp.to_i > 1
  end

  def is_readable?(filename, level='u')

    res = file(filename)

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

  def is_service?(service, cache=true)
    services = self.get_services(cache)
    services.has_key?(service)
  end

  def is_service_running?(service, cache=true)
    services = self.get_services(cache)

    if services.has_key?(service)
      services[service].eql?('running').true?
    else
      false
    end
  end

  def is_user?(user, cache=true)
    users = self.get_users(cache)
    users.has_key?(user)
  end

  def is_user_in_group?(user, group, cache=true)
    users  = self.get_users(cache)
    groups = self.get_groups(cache)

    users.has_key?(user) and groups.has_key?(group) and groups[group][:users].member?(user)
  end

  def is_writeable?(filename, level='u')

    res = file(filename)

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
          when 'x', 't'
            # is 't' really right here? copying Salesforce::Vagrant
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

    res[:directory?]  = tokens[0][0].chr.eql?('d')
    res[:file?]       = ! res[:directory?]
    res[:executable?] = [ tokens[0][3].chr.eql?('x'), tokens[0][6].chr.eql?('x'), tokens[0][9].chr.eql?('x') || tokens[0][9].chr.eql?('t') ]
    res[:writeable?]  = [ tokens[0][2].chr.eql?('w'), tokens[0][5].chr.eql?('w'), tokens[0][8].chr.eql?('w') ]
    res[:readable?]   = [ tokens[0][1].chr.eql?('r'), tokens[0][4].chr.eql?('r'), tokens[0][7].chr.eql?('r') ]

    res
  end

end
