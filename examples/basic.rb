require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'

p = Rouster.new(:name => 'app', :verbosity => 1)

p.up()
p p.status()
p.suspend()
p p.status()
p.up()
p p.status()
p.destroy()
p p.status()

exit!
