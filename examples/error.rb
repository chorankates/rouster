require '../spec_helper'

begin
  badkey = Rouster.new(:name => 'whatever', :verbosity => 4, :sshkey => __FILE__)
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
rescue => e
  p "caught unexpected #{e.class}: #{e.message}"
end

p badkey

# TODO need to do some work here, Vagrant unceremoniously appends 'Vagrantfile' into our list of vagrantfiles, when we actually want to trip an exception
begin
  badvagrantfile = Rouster.new(:name => 'likehesaid', :vagrantfile => 'dne')
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
rescue => e
  p "caught unexpected #{e.class}: #{e.message}"
end

p badvagrantfile

begin
  good = Rouster.new(:name => 'app', verbosity => 4)
rescue => e
  p "caught unexpected exception #{e.class}: #{e.message}"
end

p good
