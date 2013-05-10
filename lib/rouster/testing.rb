require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# TODO is this the right name? so close to 'tests'

class Rouster

  def validate_file(filename, options)
    raise NotImplementedError.new()
  end

  def validate_package(package, options)
    raise NotImplementedError.new()
  end

end
