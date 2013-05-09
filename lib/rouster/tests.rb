require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# TODO need to move validate_* out, no need to contribute to the namespace confusion

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
      # TODO need to mimic Salesforce::piab::_get_properties() behavior somehow
      # stick it in self somewhere, but .. where? get_output()? it wouldn't be a string, we'd parse it into a hash
      true
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
      true
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

  def validate_file(filename, options)
    raise NotImplementedError.new()
  end

  def validate_package(package, options)
    raise NotImplementedError.new()
  end

end
