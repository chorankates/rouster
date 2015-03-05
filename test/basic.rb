require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'rouster/tests'

#a = Rouster.new(:name => 'app', :verbosity => 1, :vagrantfile => '../piab/Vagrantfile', :retries => 3)
#p = Rouster.new(:name => 'ppm', :verbosity => 1, :vagrantfile => '../piab/Vagrantfile')
#r = Rouster.new(:name => 'app', :verbosity => 1, :vagrantfile => 'Vagrantfile')
l = Rouster.new(:name => 'local', :passthrough => { :type => :local }, :verbosity => 3)

p 'DBGZ' if nil?
