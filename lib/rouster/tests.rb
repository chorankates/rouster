require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rouster/deltas'

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

end
