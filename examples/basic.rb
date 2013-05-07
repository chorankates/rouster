require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'

a = Rouster.new(:name => 'ppm', :verbosity => 1)

p 'DBGZ' if nil.nil?

exit!
