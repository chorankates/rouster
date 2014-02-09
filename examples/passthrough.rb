require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

verbosity = ENV['VERBOSE'].nil? ? 4 : 0

# .inspect of this is blank for sshkey and status, looks ugly, but is ~accurate.. fix this?
local = Rouster.new(
  :name        => 'local',
  :sudo        => false,
  :passthrough => { :type => :local },
  :verbosity   => verbosity,
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
  :verbosity => verbosity,
)

sudo = Rouster.new(
  :name        => 'sudo',
  :sudo        => true,
  :passthrough => { :type => :local },
  :verbosity   => verbosity,
)

vagrant = Rouster.new(
  :name        => 'ppm',
  :sudo        => true,
  :verbosity   => verbosity,
)

workers = [ local, remote, vagrant ]

workers = [vagrant]

workers.each do |r|
  p r

  ## vagrant command testing
  r.up()
  r.suspend()
  #r.destroy()
  r.up()

  p r.status() # why is this giving us nil after initial call? want to blame caching, but not sure

  r.is_vagrant_running?()
  r.sandbox_available?()

  if r.sandbox_available?()
    r.sandbox_on()
    r.sandbox_off()
    r.sandbox_rollback()
    r.sandbox_commit()
  end

  p r.run('echo foo')

end

exit