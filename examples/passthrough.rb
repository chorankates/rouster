require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/tests'

local = Rouster.new(
  :name        => 'unnecessary value, but could be hostname',
  :sudo        => false,
  :passthrough => { :type => :local },
  :verbosity   => 4,
)

remote = Rouster.new(
  :name => 'unnecessary',
  :sudo => false,
  :passthrough => {
    :type => :remote,
    :host => `hostname`.chomp,
    :user => ENV['USER'],
    :key  => sprintf('%s/.ssh/id_dsa.pub', ENV['HOME']),
  },
  :verbosity => 4,
)

workers = [ local, remote ]

workers.each do |r|
  p r.up()
  p r.run('echo foo')
end

exit