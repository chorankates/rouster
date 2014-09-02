#!/usr/bin/ruby
## aws.rb - provide helper functions for Rouster objects running on AWS/EC2

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'

class Rouster::Provider::AWS

  #(input is AMI ID, size, keypair, userdata)

  def aws_configure (ami, size, keypair, userdata=nil)

  end

  def aws_get_ip ()

  end

  def aws_setup_vm ()
    # wait for machine to transition to running state
  end

  def aws_connect_to_elb (id, elbname, listeners = { 'InstancePort' => 22, 'LoadbalancerPort' => 22, 'InstanceProtocol' => 'TCP' })
    # TODO should we separate the elb creation to another method? probably
  end

  def aws_bootstap
    # in r2dib.rb, we upload hostname setter/r2puppet rpm - this should take an array of commands
  end

  def aws_destroy_vm
    # TODO should we really implement this separately from destroy? or should we overload?
  end

  def aws_is_running
    # TODO should we really implement this separately from destroy?
  end

  def aws_run_command
    # TODO should we really implelement this separately from 'run'?
  end

end
