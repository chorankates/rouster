require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# TODO reconsider the name - maybe this should be 'files'
#  and then move is_file(), is_in_file() and is_dir() out of rouster and into here

class Test < Rouster

  def is_executable?(filename)
    raise NotImplementedError.new()
  end

  def is_in_path?(filename)
    raise NotImplementedError.new()
  end

  def is_group?(group)
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
