require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster_aws' # brings in fog and some helpers

aws = Rouster.new(
    :name      => 'aws-testing',
    :sudo      => true,
    :passthrough => {
        # all required settings
        :type    => :aws,

        :ami     => 'ami-e1397cd1', # TODO default this to some RHEL image, also should support specifying an existing instance
        :user    => 'cloud-user',
        :sshkey  => sprintf('%s/.ssh/id_rsa-aws', ENV['HOME']),
        :keypair => 'conor@aws',

        # optional, setting to be explicit
        :size      => 't1.micro',
        :region    => 'us-west2',
        :min_count => 1, # TODO don't know how to actually handle multiple machines..
        :max_count => 1,

        :key      => ENV['AWS_ACCESS_KEY_ID'],
        :secret   => ENV['AWS_SECRET_ACCESS_KEY'],
        :endpoint => ENV['EC2_URL'],
    },
    :verbosity => 3,
)

aws.up
p aws.status
p aws.aws_get_ip
p aws.aws_get_id

p aws.run('uptime')

p 'DBGZ' if nil?

exit
