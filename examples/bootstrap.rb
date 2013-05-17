require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

app = Rouster.new(:name => 'app', :verbosity => 4, :sudo => true)
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
  p sprintf('%s available via ssh: %s', w.name, w.is_available_via_ssh?())

  p 'suspending the box'
  w.suspend()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.is_available_via_ssh?())

  p 'bringing the box back'
  w.up()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.is_available_via_ssh?())

  # put a file on the box and then bring it back
  w.put(__FILE__, '/tmp/foobar')
  w.get('/tmp/foobar', 'foobar_from_piab_host')

  # output should be the same
  p sprintf('%s uname -a via run:    %s', w.name, w.run('uname -a'))
  p sprintf('%s uname -a via output: %s', w.name, w.get_output())

  p sprintf('%s fizzy:    %s', w.name, w.run('fizzy'))
  p sprintf('%s ls /dne/  %s', w.name, w.run('ls /dne/'))

  # tear the box down
  w.destroy()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w, w.is_available_via_ssh?())

  p w.is_dir?('/tmp')
  p w.is_executable?('/sbin/service')
  p w.is_file?('/etc/hosts')
  p w.is_group?('root')
  p w.is_in_file?('/etc/hosts', 'puppet')
  p w.is_in_path?('ping')
  p w.is_package?('libpcap')
  p w.is_readable?('/etc/hosts')
  p w.is_service?('ntp')
  p w.is_service_running?('ntp')
  p w.is_user?('root')
  p w.is_writeable?('/etc/hosts')

end

exit