# heavily influenced by https://github.com/puppetlabs/hiera/blob/master/spec/spec_helper.rb

# this gets us Rouster, still need to figure out how to find vagrant
$LOAD_PATH << File.join([File.dirname(__FILE__), 'lib'])
$LOAD_PATH << File.join([File.dirname(__FILE__), 'plugins'])
$LOAD_PATH << File.expand_path(sprintf('%s/..', File.dirname(__FILE__)))
$LOAD_PATH << File.dirname(__FILE__)

require 'rubygems'

# debugging help

class Object
  def my_methods
    # Cookbook implementation
    # my_super = self.class.superclass
    # my_super ? methods - my_super.methods : methods
    (methods - Object.methods).sort
  end
end
