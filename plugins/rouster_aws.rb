#!/usr/bin/ruby
## rouster_aws.rb - provide helper functions for Rouster objects running on AWS/EC2

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'

class Rouster

  def aws_get_ip (method = :internal, type = :public)
    # allowed methods: :internal (check meta-data inside VM), :aws (ask API)
    # allowed types:   :public, :private
    p 'DBGZ'
  end

  def aws_setup_vm ()
    # wait for machine to transition to running state
    p 'DBGZ'
  end

  def aws_connect_to_elb (id, elbname, listeners = { 'InstancePort' => 22, 'LoadbalancerPort' => 22, 'InstanceProtocol' => 'TCP' })
    # TODO should we separate the elb creation to another method? probably
    p 'DBGZ'
  end

  def aws_bootstap(commands)
    # in r2dib.rb, we upload hostname setter/r2puppet rpm - this should take an array of commands
    p 'DBGZ'
  end

end
