require 'rubygems'
require 'lib/rouster'

begin
  badkey = Rouster.new(:sshkey => 'foo', :verbose => 4, :name => 'whatever')
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
end

p badkey

begin
  badvagrantfile = Rouster.new(:vagrantfile => 'foo', :verbose => 4, :name => 'likehesaid')
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
end

p badvagrantfile
