require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

class Rouster

  def is_dir?(dir)
    begin
      res = self.run(sprintf('ls -ld %s', dir))
    rescue RemoteExecutionError
      # noop, process output instead of exit code
    end

    if res.match(/No such file or directory/)
      return false
    elsif res.match(/Permission denied/)
      self.log.info(sprintf('is_dir?(%s) output[%s], try with sudo', dir, res)) unless self.uses_sudo?
      return false
    else
      #true
      parse_ls_string(res)
    end
  end

  def is_executable?(filename)
    raise NotImplementedError.new()
  end

  def is_file?(file)
    begin
      res = self.run(sprintf('ls -l %s', file))
    rescue RemoteExecutionError
      # noop, process output
    end

    if res.match(/No such file or directory/)
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
    raise NotImplementedError.new()
  end

  def is_in_file?(file, regex, scp=0)
    raise NotImplementedError.new()
  end

  def is_in_path?(filename)
    raise NotImplementedError.new()
  end

  def is_package?(package)
    raise NotImplementedError.new()
  end

  def is_user?(user)
    raise NotImplementedError.new()
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

    res[:dir]   = tokens[0][0].chr.eql?('d') ? true : false
    res[:mode]  = mode
    res[:owner] = tokens[2]
    res[:group] = tokens[3]
    res[:size]  = tokens[4]

    res
  end



end
