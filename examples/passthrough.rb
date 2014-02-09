require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

# .inspect of this is blank for sshkey and status, looks ugly, but is ~accurate.. fix this?
local = Rouster.new(
  :name        => 'local',
  :sudo        => false,
  :passthrough => { :type => :local },
  :verbosity   => 0,
)

remote = Rouster.new(
  :name => 'remote',
  :sudo => false,
  :passthrough => {
    :type => :remote,
    :host => `hostname`.chomp, # yep, the remote is actually local.. perhaps the right :type would be 'ssh' vs 'shellout' instead..
    :user => ENV['USER'],
    :key  => sprintf('%s/.ssh/id_dsa', ENV['HOME']),
  },
  :verbosity => 0,
)

sudo = Rouster.new(
  :name        => 'sudo',
  :sudo        => true,
  :passthrough => { :type => :local },
  :verbosity   => 0,
)

vagrant = Rouster.new(
  :name        => 'ppm',
  :sudo        => true,
  :verbosity   => 0,
)

workers = [ local, remote, vagrant ]

workers.each do |r|
  p r

  ## vagrant command testing
  r.up()
  r.suspend()
  #r.destroy()
  r.up()
  r.status()

  if ! r.is_passthrough?()
    r.is_vagrant_running?()
    r.sandbox_available?()
    r.sandbox_on()
    r.sandbox_off()
    r.sandbox_rollback()
    r.sandbox_commit()
  end

  p r.run('echo foo')


end

exit