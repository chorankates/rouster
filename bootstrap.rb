require 'rubygems'
require 'lib/rouster'

# want to be able to instantiate like this
#app = Rouster.new(:name => 'app', :sshkey => sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']))
app = Rouster.new('app', 0, nil, sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']), false)
ppm = Rouster.new('ppm', 0, nil, sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']), false)

# passthrough boxes do not need to specify a name
#lpt = Rouster.new(:passthrough => 'local', :verbosity => 4)
#rpt = Rouster.new(:passthrough => 'remote', :verbosity => 4, :sshkey => '~/.ssh/id_dsa')

workers = [app, ppm]

workers.each do |w|
  p '%s config: ' % w.name
  p w

  p 'status: %s' % w.status()
  p 'upping the box'
  w.up()

  p '%s status: %s' % w, w.status()
  p '%s available via ssh: %s' % w, w.available_via_ssh?()

  p 'suspending the box'
  w.suspend()

  p '%s status: %s' % w, w.status()
  p '%s available via ssh: %s' % w, w.available_via_ssh?()

  p 'bringing the box back'
  w.up()

  p '%s status: %s' % w, w.status()
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