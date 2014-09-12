require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster_aws' # brings in fog and some helpers

aws = Rouster.new(
    :name      => 'aws-testing',
    :sudo      => false,
    :passthrough => {
        # all required settings
        :type            => :aws,
        :keypair         => 'conor@aws',
        :security_groups => 'integration-testing',
        :key             => sprintf('%s/.ssh/id_rsa-aws', ENV['HOME']),
        :userdata        => 'foo',

        # optional, setting to be explicit
        :ami       => 'ami-7bdaa84b', # TODO should support specifying an existing instance (either :ami or :instance)
        :min_count => 1, # TODO don't know how to actually handle multiple machines.. just do the same thing on all of the hosts?
        :max_count => 1,
        :region    => 'us-west-2',
        :size      => 't1.micro',
        :user      => 'ec2-user',

        :key_id       => ENV['AWS_ACCESS_KEY_ID'],
        :secret_key   => ENV['AWS_SECRET_ACCESS_KEY'],
    },
    :verbosity => 1,
)

aws.up
p aws.status
p aws.aws_status # TODO merge this into status
p aws.aws_get_ip(:internal, :public)
p aws.aws_get_ip(:internal, :private)
p aws.aws_get_ip(:aws, :public)
p aws.aws_get_ip(:aws, :private)

p aws.aws_get_id

p aws.run('uptime')
p aws.put('/etc/hosts')

p 'DBGZ' if nil?

exit
