require 'rubygems'
require 'lib/rouster'

begin
  badkey = Rouster.new('whatever', 4, __FILE__, 'foo', false)
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
rescue => e
  p "caught unexpected #{e.class}: #{e.message}"
end

p badkey

begin
  badvagrantfile = Rouster.new('likehesaid', 4, 'foo', __FILE__, false)
rescue Rouster::InternalError => e
  p "caught #{e.class}: #{e.message}"
rescue => e
  p "caught unexpected #{e.class}: #{e.message}"
end

p badvagrantfile

begin
  good = Rouster.new('app', 4, nil, '/Users/choran-kates/.vagrant.d/insecure_private_key', false)
rescue => e
  p "caught #{e.class}: #{e.message}"
end

p good
