require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'plugins/openstack' # brings in fog and some helpers

ostack = Rouster.new(
  :name      => 'ostack-testing',
  :sudo      => false,
  :logfile   => true,
  :passthrough => {
    :type                => :openstack,                                   # Indicate OpenStack provider
    :openstack_auth_url  => 'http://hostname.acme.com:5000/v2.0/tokens',  # OpenStack API endpoint
    :openstack_username  => 'some_user',                                  # OpenStack console username
    :openstack_tenant    => 'tenant_id',                                  # Tenant ID
    :user                => 'ssh_user_id',                                # SSH login ID
    :keypair             => 'openstack_key_name',                         # Name of ssh keypair in OpenStack
    :image_ref           => 'c0340afb-577d-1234-87b2-aebdd6d1838f',       # Image ID in OpenStack
    :flavor_ref          => '547d9af5-096c-1234-98df-7d23162556b8',       # Flavor ID in OpenStack
    :openstack_api_key   => 'secret_openstack_key',                       # OpenStack console password
    :key                 => '/path/to/ssh_keys.pem',                      # SSH key filename
  },
  :sshtunnel => false,
)

p "UP(): #{ostack.up}"
p "STATUS(): #{ostack.status}"

ostack_copy = Rouster.new(
  :name      => 'ostack-copy',
  :sudo      => false,
  :logfile   => true,
  :passthrough => {
    :type                => :openstack,                                   # Indicate OpenStack provider
    :openstack_auth_url  => 'http://hostname.acme.com:5000/v2.0/tokens',  # OpenStack API endpoint
    :openstack_username  => 'some_user',                                  # OpenStack console username
    :openstack_tenant    => 'tenant_id',                                  # Tenant ID
    :user                => 'ssh_user_id',                                # SSH login ID
    :keypair             => 'openstack_key_name',                         # Name of ssh keypair in OpenStack
    :openstack_api_key   => 'secret_openstack_key',                       # OpenStack console password
    :instance            => ostack.ostack_get_instance_id,                # ID of a running OpenStack instance.
  },
  :sshtunnel => false,
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
