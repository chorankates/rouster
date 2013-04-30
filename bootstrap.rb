require 'rubygems'
require 'lib/rouster'


app = Rouster.new(:name => 'app')
ppm = Rouster.new(:name => 'ppm', :verbosity => 4, :vagrantfile => '../piab/Vagrantfile')

# passthrough boxes do not need to specify a name
lpt = Rouster.new(:passthrough => 'local', :verbosity => 4)
#rpt = Rouster.new(:passthrough => 'remote', :verbosity => 4, :sshkey => '~/.ssh/id_dsa')

workers = [app, ppm, lpt]

workers.each do |w|

  p '%s config: ' % w.name
  p 'passthrough: %s' % w.passthrough
  p 'sshkey:      %s' % w.sshkey
  p 'wagrantfile: %s' % w.vagrantfile

  w.up()

  p '%s status: %s' % w, w.status()
  p '%s available via ssh: %s' % w, w.available_via_ssh?()

  w.suspend()

  p '%s status: %s' % w, w.status()
  p '%s available via ssh: %s' % w, w.available_via_ssh?()

  w.up()

  p '%s available via ssh: %s' % w, w.available_via_ssh?()

  # put a file on the box and then bring it back
  w.put(__FILE__, '/tmp/foobar')
  w.get('/tmp/foobar', 'foobar_from_piab_host')

  # output should be the same
  p '%s uname -a via run:    %s' % w, w.run('uname -a')
  p '%s uname -a via output: %s' % w, w.output()

  # tear the box down
  w.destroy()

  p '%s status: %s' % w, w.status()
  p '%s available via ssh: %s' % w, w.available_via_ssh?()

end