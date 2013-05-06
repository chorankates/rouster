require '../path_helper'

class Puppet
  include 'rouster'

  def compile_catalog
    raise NotImplementedError.new()
  end

  def get_puppet_errors(input)
    raise NotImplementedError.new()
  end

  def get_puppet_notices(input)
    raise NotImplementedError.new()
  end

end