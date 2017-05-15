require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

app = Rouster.new(:name => 'app', :sudo => true)
ppm = Rouster.new(:name => 'ppm', :sudo => true)

# passthrough boxes do not need to specify a name
# commented out currently because passthrough is not MVP
#lpt = Rouster.new(:passthrough => 'local')
#rpt = Rouster.new(:passthrough => 'remote', :sshkey => '~/.ssh/id_dsa')

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

  ## expected success
  p sprintf('is_dir?(/tmp): %s', w.is_dir?('/tmp'))
  p sprintf('is_exectuable?(/sbin/service: %s', w.is_executable?('/sbin/service'))
  p sprintf('is_file?(/etc/hosts): %s', w.is_file?('/etc/hosts'))
  p sprintf('is_group?(root): %s', w.is_group?('root'))
  p sprintf('is_in_file?(/etc/hosts, puppet): %s', w.is_in_file?('/etc/hosts', 'puppet'))
  p sprintf('is_in_path?(ping): %s', w.is_in_path?('ping'))
  p sprintf('is_package?(libpcap): %s', w.is_package?('libpcap'))
  p sprintf('is_port_open?(9999): %s', w.is_port_open?(9999))
  p sprintf('is_port_active?(22): %s', w.is_port_active?(22))
  p sprintf('is_process_running?(sshd): %s', w.is_process_running?('sshd'))
  p sprintf('is_readable?(/etc/hosts): %s', w.is_readable?('/etc/hosts'))
  p sprintf('is_service?(iptables): %s', w.is_service?('iptables'))
  p sprintf('is_service_running?(iptables): %s', w.is_service_running?('iptables'))
  p sprintf('is_user?(root): %s', w.is_user?('root'))
  p sprintf('is_writeable?(/etc/hosts): %s', w.is_writeable?('/etc/hosts'))

  ## expected failure
  p sprintf('is_dir?(/dne): %s', w.is_dir?('/dne'))
  p sprintf('is_executable?(fizzybang): %s', w.is_executable?('fizzybang'))
  p sprintf('is_file?(/dne/fizzy): %s', w.is_file?('/dne/fizzy'))
  p sprintf('is_group?(three-amigos): %s', w.is_group?('three-amigos'))
  p sprintf('is_in_file?(/etc/hosts, this content is not there): %s', w.is_in_file?('/etc/hosts', 'this content is not there'))
  p sprintf('is_in_file?(/dne/fizzy, this file is not there): %s', w.is_in_file?('/dne/fizzy', 'this file is not there'))
  p sprintf('is_in_path?(fizzy): %s', w.is_in_path?('fizzy'))
  p sprintf('is_package?(fizzybang): %s', w.is_package?('fizzybang'))
  p sprintf('is_port_open?(123, udp): %s', w.is_port_open?(123, 'udp'))
  p sprintf('is_port_open?(22): %s', w.is_port_open?(22))
  p sprintf('is_process_running?(fizzy): %s', w.is_process_running?('fizzy'))
  p sprintf('is_readable?(/dne/fizzy): %s', w.is_readable?('/dne/fizzy'))
  p sprintf('is_service?(syslogd): %s', w.is_service?('syslogd'))
  p sprintf('is_service_running?(smartd): %s', w.is_service_running?('smartd'))
  p sprintf('is_user?(toor): %s', w.is_user?('toor'))
  #p sprintf('is_writable?(/etc/hosts): %s', w.is_writeable?('/etc/hosts')) # running as sudo, so everything is writeable -- can we test this with a file in a path that DNE?

  # put a file on the box and then bring it back
  w.put(__FILE__, '/tmp/foobar')
  w.get('/tmp/foobar', 'foobar_from_piab_host.tmp')

  # output should be the same
  p sprintf('%s uname -a via run:    %s', w.name, w.run('uname -a'))
  p sprintf('%s uname -a via output: %s', w.name, w.get_output())

  begin
    p sprintf('%s fizzy:    %s', w.name, w.run('fizzy'))
  rescue => e
    p e
  end

  begin
    p sprintf('%s ls /dne/  %s', w.name, w.run('ls /dne/'))
  rescue => e
    p e
  end

  p sprintf('%s ls /dne/ expected exit code 2: %s', w.name, w.run('ls /dne/', 2))

  # tear the box down
  p 'destroying the box'
  w.destroy()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.is_available_via_ssh?())

  # bring it back again
  p 'upping the box again'
  w.up()

  p sprintf('%s status: %s', w.name, w.status())
  p sprintf('%s available via ssh: %s', w.name, w.is_available_via_ssh?())

end

exit