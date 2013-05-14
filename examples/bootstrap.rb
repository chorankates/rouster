require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

app = Rouster.new(:name => 'app', :verbosity => 2, :sudo => false)
ppm = Rouster.new(:name => 'ppm', :verbosity => 1, :sudo => true)

# passthrough boxes do not need to specify a name
# commented out currently because passthrough is not MVP
#lpt = Rouster.new(:passthrough => 'local', :verbosity => 4)
#rpt = Rouster.new(:passthrough => 'remote', :verbosity => 4, :sshkey => '~/.ssh/id_dsa')

workers = [app]

workers.each do |w|
  p '%s config: ' % w.name
  p w

  p 'status: %s' % w.status()
  p 'upping the box'
  w.up()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.available_via_ssh?())

  p 'suspending the box'
  w.suspend()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.available_via_ssh?())

  p 'bringing the box back'
  w.up()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.available_via_ssh?())

  # put a file on the box and then bring it back
  w.put(__FILE__, '/tmp/foobar')
  w.get('/tmp/foobar', 'foobar_from_piab_host')

  # output should be the same
  p sprintf('%s uname -a via run:    %s', w.name, w.run('uname -a'))
  p sprintf('%s uname -a via output: %s', w.name, w.get_output())

  # tear the box down
  w.destroy()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w, w.available_via_ssh?())

end

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

app = Rouster.new(:name => 'app', :verbosity => 1)

#print p.put(__FILE__, '/tmp/foobar')
print app.get('/tmp/foobar', '/tmp/frobnozzle')

print app.is_dir?('/tmp')
print app.is_executable?('/sbin/service')
print app.is_file?('/etc/hosts')
print app.is_group?('root')
print app.is_in_file?('/etc/hosts', 'puppet')
print app.is_in_path?('ping')
print app.is_package?('libpcap')
print app.is_readable?('/etc/hosts')
print app.is_service?('ntp')
print app.is_service_running?('ntp')
print app.is_user?('root')
print app.is_writeable?('/etc/hosts')

exit!

app.run('uname -a')
print "output: #{app.get_output()} / exitcode: #{app.exitcode}\n"
begin
  app.run('fizzbang')
  print "output: #{app.get_output()} / exitcode: #{app.exitcode}\n"
rescue Rouster::RemoteExecutionError => e
  print "caught an exception: #{e}"
end

exit

app.up()
p app.status()
app.suspend()
p app.status()
app.up()
p app.status()
app.destroy()
p app.status()

exit!
