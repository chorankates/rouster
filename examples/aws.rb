require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'plugins/aws' # brings in fog and some helpers

aws_already_running = Rouster.new(
  :name        => 'aws-already-running',
  :passthrough => {
    :type     => :aws,
    :instance => 'your-instance-id',
    :key      => sprintf('%s/.ssh/id_rsa-aws', ENV['HOME'])
  },
  :verbosity => 1,
)

a = aws_already_running.run('ls -l /etc/hosts; who')

aws = Rouster.new(
  :name      => 'aws-testing',
  :sudo      => false,
  :passthrough => {
    # all required settings
    :type            => :aws,
    :keypair         => 'your-keypair-name',
    :security_groups => 'integration-testing',
    :key             => sprintf('%s/.ssh/id_rsa-aws', ENV['HOME']),
    :userdata        => 'foo',

    # optional, setting to be explicit
    :ami                   => 'your-ami-id',
    :dns_propagation_sleep => 20,
    :min_count             => 1, # TODO don't know how to actually handle multiple machines.. just do the same thing on all of the hosts?
    :max_count             => 1,
    :region                => 'us-west-2',
    :size                  => 't1.micro',
    :ssh_port              => 22,
    :user                  => 'ec2-user',

    :key_id       => ENV['AWS_ACCESS_KEY_ID'],
    :secret_key   => ENV['AWS_SECRET_ACCESS_KEY'],
  },
  :sshtunnel => false,
  :verbosity => 1,
)

p "up(): #{aws.up}"

aws_clone = Rouster.new(
  :name => 'aws-testing-clone',
  :passthrough => {
    :type     => :aws,
    :key      => sprintf('%s/.ssh/id_rsa-aws', ENV['HOME']),
    :instance => aws.aws_get_instance,
  },
  :verbosity => 1,
)

[ aws, aws_already_running, aws_clone ].each do |a|
  p "aws_get_ami: #{a.aws_get_ami}"
  p "aws_get_instance: #{a.aws_get_instance}"

  p "status: #{a.status}"
  p "aws_status: #{a.aws_status}" # TODO merge this into status

  p "aws_get_ip(:internal, :public): #{a.aws_get_ip(:internal, :public)}"
  p "aws_get_ip(:internal, :private): #{a.aws_get_ip(:internal, :private)}"
  p "aws_get_ip(:aws, :public): #{a.aws_get_ip(:aws, :public)}"
  p "aws_get_ip(:aws, :private): #{a.aws_get_ip(:aws, :private)}"

  p "aws_get_hostname(:internal, :public): #{a.aws_get_hostname(:internal, :public)}"
  p "aws_get_hostname(:internal, :private): #{a.aws_get_hostname(:internal, :private)}"
  p "aws_get_hostname(:aws, :public): #{a.aws_get_hostname(:aws, :public)}"
  p "aws_get_hostname(:aws, :private): #{a.aws_get_hostname(:aws, :private)}"

  p "run(uptime): #{a.run('uptime')}"
  p "get(/etc/hosts): #{a.get('/etc/hosts')}"
  p "put(/etc/hosts, /tmp): #{a.put('/etc/hosts', '/tmp')}"

  p "aws_get_userdata: #{a.aws_get_userdata}"
  p "aws_get_metadata: #{a.aws_get_metadata}"

  p 'DBGZ' if nil?
end

exit
