require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

p = Rouster.new(:name => 'app', :verbosity => 1)

p.up()
p.run('uname -a')
print "output: #{p.get_output()} / exitcode: #{p.exitcode}\n"

print p.is_dir?('/tmp')
print p.is_dir?('/tmp/')
print p.is_dir?('/bang')

print p.is_file('/etc/hosts')
print p.is_file('foo')

begin
  p.run('fizzbang')
  print "output: #{p.get_output()} / exitcode: #{p.exitcode}\n"
rescue Rouster::RemoteExecutionError => e
  print "caught an exception: #{e}"
end

exit

p.up()
p p.status()
p.suspend()
p p.status()
p.up()
p p.status()
p.destroy()
p p.status()

exit!
