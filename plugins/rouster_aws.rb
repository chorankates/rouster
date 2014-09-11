#!/usr/bin/ruby
## rouster_aws.rb - provide helper functions for Rouster objects running on AWS/EC2

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'
require 'uri'

class Rouster

  attr_reader :ec2, :elb     # expose AWS workers
  attr_reader :instance_data # the result of the runInstances request

  def aws_get_ip (method = :internal, type = :public)
    # allowed methods: :internal (check meta-data inside VM), :aws (ask API)
    # allowed types:   :public, :private
    result = nil

    if method.equal?(:internal)
      murl = sprintf('http://169.254.169.254/latest/meta-data/%s', type.to_s) # TODO probably should have some validation that the type is public|private

      result = get_url(murl)
    else
      # TODO pull this from @instance_data
      #return @instance_data[]
      p 'DBGZ'
    end

    result
  end

  def aws_get_id ()
    # TODO return this from @instance_data
    p 'DBGZ'
    #return @instance_data[]
  end

  def aws_up
    # wait for machine to transition to running state
    self.aws_connect

    server = @ec2.run_instances(
        self.passthrough[:ami],
        self.passthrough[:min_count],
        self.passthrough[:max_count],
        {
          'InstanceType' => self.passthrough[:size],
          'KeyPair'      => self.passthrough[:keypair],
          'UserData'     => self.passthrough[:userdata],
        },
    )

    # TODO not sure i like this model
    #server.wait_for { ready? }

    @instance_data = nil
    p 'DBGZ'
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

    @ec2 = Fog::Compute.new({
      :provider              => 'AWS',
      :endpoint              => self.passthrough[:ec2_endpoint],
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
