require '../spec_helper'
require 'rouster'

app = Rouster.new(:name => 'app', :verbosity => 2, :sudo => false)
#ppm = Rouster.new(:name => 'ppm', :verbosity => 4, :sudo => true)

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

  # saving battery life
  if false
    p 'suspending the box'
    w.suspend()

    p sprintf('%s status: %s', w.name, w.status())
    p sprintf('%s available via ssh: %s', w.name, w.available_via_ssh?())

    p 'bringing the box back'
    w.up()

    p sprintf('%s status: %s' % w.name, w.status())
    p sprintf('%s available via ssh: %s', w.name, w.available_via_ssh?())
  end

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