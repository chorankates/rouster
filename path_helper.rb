# heavily influenced by https://github.com/puppetlabs/hiera/blob/master/spec/spec_helper.rb

# this gets us Rouster, still need to figure out how to find vagrant
$LOAD_PATH << File.join([File.dirname(__FILE__), "lib"])

require 'rubygems'

## this is really optional, so don't die if we don't have it
begin
  require 'ruby-debug'
rescue LoadError
end

# debugging help
class Object
  def my_methods
    # Cookbook implementation
    # my_super = self.class.superclass
    # my_super ? methods - my_super.methods : methods
    (methods - Object.methods).sort
  end
end
