#!/usr/bin/ruby
## rouster_aws.rb - provide helper functions for Rouster objects running on AWS/EC2

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'

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

    p 'DBGZ'

    server = @ec2.servers.create(
        # this instantiation is wrong
        :image_id      => self.passthrough[:ami],
        :image_keypair => self.passthrough[:keypair],
        :image_size    => self.passthrough[:size],
        :region        => self.passthrough[:region],
        :min_count     => self.passthrough[:min_count],
        :max_count     => self.passthrough[:max_count],
    )

    # TODO not sure i like this model
    server.wait_for { ready? }

    @instance_data = nil
    p 'DBGZ'
  end

  def aws_connect_to_elb (id, elbname, listeners = { 'InstancePort' => 22, 'LoadbalancerPort' => 22, 'InstanceProtocol' => 'TCP' })
    self.elb_connect

    p 'DBGZ'
  end

  def aws_bootstap (commands)
    self.aws_connect
    commands = (commands.is_a?(Array)) ? commands : [ commands ]

    commands.each do |command|
      @logger.debug(sprintf('about to run[%s]', command))
    end

  end

  private

  def aws_connect
    return @ec2 unless @ec2.nil?

    @ec2 = Fog::Compute.new({
      :provider              => 'AWS',
      :aws_access_key_id     => self.passthrough[:key],
      :aws_secret_access_key => self.passthrough[:secret],
    })
  end

  def elb_connect
    return @elb unless @elb.nil?

    @elb = Fog::AWS::ELB.new({
      :aws_access_key_id     => self.passthrough[:key],
      :aws_secret_access_key => self.passthrough[:secret],
    })
  end

end
