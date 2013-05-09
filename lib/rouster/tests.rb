require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

class Rouster

  def is_dir?(dir)
    raise NotImplementedError.new()
  end

  def is_executable?(filename)
    raise NotImplementedError.new()
  end

  def is_file?(file)
    raise NotImplementedError.new()
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
