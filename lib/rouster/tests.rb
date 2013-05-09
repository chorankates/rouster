require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# TODO need to move validate_* out, no need to contribute to the namespace confusion

class Rouster

  def is_dir?(dir)
    res = self.run(sprintf('ls -l %s', dir))

    if res.grep(/No such file or directory/)
      return false
    elsif res.grep(/Permission denied/)
      return false
    else
      # TODO need to mimic Salesforce::piab::_get_properties() behavior somehow
      # stick it in self somewhere, but .. where?
      true
    end
  end

  def is_executable?(filename)
    raise NotImplementedError.new()
  end

  def is_file?(file)
    res = self.run(sprintf('ls -l %s', file))

    if res.grep(/No such file or directory/)
      return false
    elsif res.grep(/Permission denied/)
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
