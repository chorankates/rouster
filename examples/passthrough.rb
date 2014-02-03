require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

local = Rouster.new(
  :name        => 'local',
  :sudo        => false,
  :passthrough => { :type => :local },
  :verbosity   => 1,
)

remote = Rouster.new(
  :name => 'remote',
  :sudo => false,
  :passthrough => {
    :type => :remote,
    :host => `hostname`.chomp,
    :user => ENV['USER'],
    :key  => sprintf('%s/.ssh/id_dsa', ENV['HOME']),
  },
  :verbosity => 1,
)

workers = [ local, remote ]

workers.each do |r|
  p r
  p r.up()
  p r.run('echo foo')
end

exit