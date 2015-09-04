require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'plugins/openstack' # brings in fog and some helpers

ostack = Rouster.new(
  :name      => 'ostack-testing',
  :sudo      => false,
  :logfile   => true,
  :passthrough => {
    :type                => :openstack,
    :openstack_auth_url  => 'http://hostname.acme.com:5000/v2.0/tokens',
    :openstack_username  => 'some_user',
    :openstack_tenant    => 'tenant_id',
    :user                => 'ssh_user_id',
    :keypair             => 'openstack_key_name',
    :image_ref           => 'c0340afb-577d-1234-87b2-aebdd6d1838f',
    :flavor_ref          => '547d9af5-096c-1234-98df-7d23162556b8',
    :openstack_api_key   => 'secret_openstack_key',
    :key                 => '/path/to/ssh_keys.pem',
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
    :type                => :openstack,
    :openstack_auth_url  => 'http://hostname.acme.com:5000/v2.0/tokens',
    :openstack_username  => 'some_user',
    :openstack_tenant    => 'tenant_id',
    :user                => 'ssh_user_id',
    :keypair             => 'openstack_key_name',
    :openstack_api_key   => 'secret_openstack_key',
    :instance            => ostack.ostack_get_instance_id,
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
