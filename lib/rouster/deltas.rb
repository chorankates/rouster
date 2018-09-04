require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# deltas.rb - get information about crontabs, groups, packages, ports, services and users inside a Vagrant VM
require 'rouster'
require 'rouster/tests'

require 'rouster/deltas/crontab'
require 'rouster/deltas/groups'
require 'rouster/deltas/packages'
require 'rouster/deltas/ports'
require 'rouster/deltas/services'
require 'rouster/deltas/users'