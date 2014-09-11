#!/usr/bin/ruby
## rouster_aws.rb - provide helper functions for Rouster objects running on AWS/EC2

# TODO implement some caching of AWS data?

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'
require 'uri'

require 'pry'

class Rouster

  attr_reader :ec2, :elb     # expose AWS workers
  attr_reader :instance_data # the result of the runInstances request

  # TODO should this be 'aws_ip'?
  def aws_get_ip (method = :internal, type = :public)
    # allowed methods: :internal (check meta-data inside VM), :aws (ask API)
    # allowed types:   :public, :private
    self.describe_instance

    result = nil

    if method.equal?(:internal)
      key    = type.equal?(:public) ? 'public-ipv4' : 'local-ipv4'
      murl   = sprintf('http://169.254.169.254/latest/meta-data/%s', key)
      result = self.run(sprintf('curl %s', murl))
    else
      key    = type.equal?(:public) ? 'ipAddress' : 'privateIpAddress'
      result = @instance_data[key]
    end

    result
  end

  def aws_get_id ()
    @instance_data['instanceId']
  end

  def aws_up
    # wait for machine to transition to running state
    self.aws_connect

    ceiling    = 9
    sleep_time = 20
    server  = @ec2.run_instances(
        self.passthrough[:ami],
        self.passthrough[:min_count],
        self.passthrough[:max_count],
        {
          'InstanceType'   => self.passthrough[:size],
          'KeyName'        => self.passthrough[:keypair],
          'SecurityGroup'  => self.passthrough[:security_groups],
          'UserData'       => self.passthrough[:userdata],

        },
    )

    # TODO don't be this hacky
    @instance_data = server.data[:body]['instancesSet'][0]
    @passthrough[:host] = @instance_data['dnsName']
    @passthrough[:port] = "22"

    0.upto(ceiling) do |try|
      status = self.aws_status

      @logger.debug(sprintf('describeInstances[%s]: [%s] [#%s]', self.aws_get_id, status, try))

      if status.eql?('running') or status.eql?('16')
        @logger.info(sprintf('[%s] transitioned to state[%s]', self.aws_get_id, self.aws_status))
        break
      end

      sleep sleep_time
    end

    self.aws_get_id
  end

  def aws_destroy
    self.aws_connect

    server = @ec2.terminate_instances(self.aws_get_id)

    self.aws_status
  end

  def describe_instance
    self.aws_connect
    server         = @ec2.describe_instances('instance-id' => [ @instance_data['instanceId'] ])
    @instance_data = server.data[:body]['reservationSet'][0]['instancesSet'][0]
  end

  def aws_status
    self.describe_instance
    @instance_data['instanceState']['name'].nil? ? @instance_data['instanceState']['code'] : @instance_data['instanceState']['name']
  end

  def aws_connect_to_elb (id, elbname, listeners = [{ 'InstancePort' => 22, 'LoadbalancerPort' => 22, 'InstanceProtocol' => 'TCP' }])
    self.elb_connect

    # allow either hash or array of hash specification for listeners
    listeners       = [ listeners ] unless listeners.is_a?(Array)
    required_params = [ 'InstancePort', 'LoadbalancerPort', 'InstanceProtocol' ]

    listeners.each do |l|
      required_params.each do |r|
        raise sprintf('listener[%s] does not include required parameter[%s]', l, r) unless l[r]
      end

    end

    ## ok, everything is validated, lets do this

  end

  def aws_bootstap (commands)
    self.aws_connect
    commands = (commands.is_a?(Array)) ? commands : [ commands ]

    commands.each do |command|
      @logger.debug(sprintf('about to run[%s]', command))
    end

  end

  def aws_connect
    return @ec2 unless @ec2.nil?

    # TODO only use self.passthrough[:ec2_endpoint] if it isn't null
    @ec2 = Fog::Compute.new({
      :provider              => 'AWS',
      :region                => self.passthrough[:region],
      :aws_access_key_id     => self.passthrough[:key],
      :aws_secret_access_key => self.passthrough[:secret],
    })
  end

  def elb_connect
    return @elb unless @elb.nil?

    endpoint = URI.parse(self.passthrough[:elb_endpoint])

    @elb = Fog::AWS::ELB.new({
      :host   => endpoint.host,
      :path   => endpoint.path,
      :port   => endpoint.port,
      :scheme => endpoint.scheme,
      :aws_access_key_id     => self.passthrough[:key],
      :aws_secret_access_key => self.passthrough[:secret],
    })
  end

end
