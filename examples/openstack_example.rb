require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'plugins/openstack' # brings in fog and some helpers

ostack = Rouster.new(
  :name      => 'ostack-testing',
  :sudo      => false,
  :logfile   => true,
  :passthrough => {
    :type                => :openstack,       # OpenStack Fog provider
    :openstack_auth_url  => 'http://hostname.domain.com:5000/v2.0/tokens',          # OpenStack Keystone endpoint
    :openstack_username  => 'some_console_user',        # OpenStack Console Username
    :openstack_tenant    => 'tenant_id',           # Tenant id
    :connection_options  => {},                                   # Optional (unused for now)
    :user                => 'ssh_user',       # SSH login id
    :keypair             => 'keypair_name',     # Name of keypair in Openstack.
    :image_ref           => 'c0340afb-577d-4db6-1234-aebdd6d1838f', # Image ID in Openstack.
    :flavor_ref          => '547d9af5-096c-44a3-1234-7d23162556b8', # Flavor ID in Openstack.
    :openstack_api_key   => 'some_api_key',               # OpenStack Console Password
    :key                 => '/etc/keys/keypair_name.pem', # SSH key file name.
  },
  :sshtunnel => false,
  :verbosity => 1,
)

p "UP(): #{ostack.up}"
p "STATUS(): #{ostack.status}"
ostack_copy = Rouster.new(
  :name      => 'ostack-copy',
  :sudo      => false,
  :logfile   => true,
  :passthrough => {
    :type                => :openstack,       # OpenStack Fog provider
    :openstack_auth_url  => 'http://hostname.domain.com:5000/v2.0/tokens',          # OpenStack Keystone endpoint
    :openstack_username  => 'some_console_user',        # OpenStack Console Username
    :openstack_tenant    => 'tenant_id',           # Tenant id
    :openstack_api_key   => 'some_api_key',               # OpenStack Console Password
    :connection_options  => {},                                   # Optional (unused for now)
    :user                => 'ssh_user',       # SSH login id
    :keypair             => 'keypair_name',     # Name of keypair in Openstack.
    :instance            => ostack.ostack_get_instance_id,   # Instance ID for already running instance.
  },
  :sshtunnel => false,
  :verbosity => 1,
)

[ ostack, ostack_copy ].each do |o|
  p "ostack_get_instance_id: #{o.ostack_get_instance_id}"

  p "status: #{o.status}"

  p "ostack_get_ip(): #{o.ostack_get_ip()}"
  p "run(uptime): #{o.run('uptime')}"
  p "get(/etc/hosts): #{o.get('/etc/hosts')}"
  p "put(/etc/hosts, /tmp): #{o.put('/etc/hosts', '/tmp')}"

end

p "DESTROY(): #{ostack.destroy}"
exit
