#!/usr/bin/ruby
## plugins/openstack.rb - provide helper functions for Rouster objects running on OpenStack/Compute

require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'fog'
require 'uri'

class Rouster

  attr_reader :nova     # expose OpenStack workers
  attr_reader :instance_data # the result of the runInstances request

  # return a hash containing meta-data items
  def ostack_get_instance_id ()
    # The instance id is kept in @passthrough[:instance] or
    # can be obtained from @instance_data which has all instance
    # details.
    if ! @instance_data.nil? and ! @instance_data.id.nil?
      return @instance_data.id # we already know the id
    elsif @passthrough.has_key?(:instance)
      return @passthrough[:instance] # we know the id we want
    else
      @logger.debug(sprintf('unable to determine id from instance_data[%s] or passthrough specification[%s]', @instance_data, @passthrough))
      return nil # we don't have an id yet, likely a up() call
    end
  end

  def ostack_up
    # wait for machine to transition to running state and become sshable (TODO maybe make the second half optional)
    self.ostack_connect
    # This will check if instance_id has been provided. If so, it will check on status of the instance.
    status = self.status()
    if status.eql?('running')
      self.passthrough[:instance] = self.ostack_get_instance_id
      @logger.debug(sprintf('Connecting to running instance [%s] while calling ostack_up()', self.passthrough[:instance]))
      self.connect_ssh_tunnel
    else
      if @passthrough[:openstack_net_id]
        # if the user has set a net id, send it along
        server = @nova.servers.create(:name => @name, :flavor_ref => @passthrough[:flavor_ref],
                  :image_ref => @passthrough[:image_ref], :nics => [{:net_id => @passthrough[:openstack_net_id] }], 
                  :key_name => @passthrough[:keypair], :user_data => @passthrough[:user_data])
      else
        server = @nova.servers.create(:name => @name, :flavor_ref => @passthrough[:flavor_ref],
                  :image_ref => @passthrough[:image_ref], :key_name => @passthrough[:keypair], :user_data => @passthrough[:user_data])
      end
      server.wait_for { ready? }
      @instance_data = server
      server.addresses.each_key do |address_key|
        if defined?(server.addresses[address_key])
          self.passthrough[:host] = server.addresses[address_key].first['addr']
          break
        end
      end
      self.passthrough[:instance] = self.ostack_get_instance_id
      @logger.debug(sprintf('Connecting to running instance [%s] while calling ostack_up()', self.passthrough[:instance]))
      self.connect_ssh_tunnel
    end
    self.passthrough[:instance]
  end

  def ostack_get_ip()
    self.passthrough[:host]
  end

  def ostack_destroy
    server = self.ostack_describe_instance
    raise sprintf("instance[%s] not found by destroy()", self.ostack_get_instance_id) if server.nil?
    server.destroy
    @instance_data = nil
    self.passthrough.delete(:instance)
  end

  def ostack_describe_instance(instance_id = ostack_get_instance_id)

    if @cache_timeout
      if @cache.has_key?(:ostack_describe_instance)
        if (Time.now.to_i - @cache[:ostack_describe_instance][:time]) < @cache_timeout
          @logger.debug(sprintf('using cached ostack_describe_instance?[%s] from [%s]', @cache[:ostack_describe_instance][:instance], @cache[:ostack_describe_instance][:time]))
          return @cache[:ostack_describe_instance][:instance]
        end
      end
    end
    # We don't have a instance.
    return nil if instance_id.nil?
    self.ostack_connect
    response = @nova.servers.get(instance_id)
    return nil if response.nil?
    @instance_data = response

    if @cache_timeout
      @cache[:ostack_describe_instance] = Hash.new unless @cache[:ostack_describe_instance].class.eql?(Hash)
      @cache[:ostack_describe_instance][:time] = Time.now.to_i
      @cache[:ostack_describe_instance][:instance] = response
      @logger.debug(sprintf('caching is_available_via_ssh?[%s] at [%s]', @cache[:ostack_describe_instance][:instance], @cache[:ostack_describe_instance][:time]))
    end

    @instance_data
  end

  def ostack_status
    self.ostack_describe_instance
    return 'not-created' if @instance_data.nil?
    if @instance_data.state.eql?('ACTIVE')
       # Make this consistent with AWS response.
       return 'running'
    else
       return  @instance_data.state
    end
  end


  # TODO this will throw at the first error - should we catch?
  # run some commands, return an array of the output
  def ostack_bootstrap (commands)
    self.ostack_connect
    commands = (commands.is_a?(Array)) ? commands : [ commands ]
    output   = Array.new

    commands.each do |command|
      output << self.run(command)
    end

    return output
  end

  def ostack_connect
    # Instantiates an Object which can communicate with OS Compute.
    # No instance specific information is set at this time.
    return @nova unless @nova.nil?

    config = {
      :provider            => 'openstack',                           # OpenStack Fog provider
      :openstack_auth_url  => self.passthrough[:openstack_auth_url], # OpenStack Keystone endpoint
      :openstack_username  => self.passthrough[:openstack_username], # Your OpenStack Username
      :openstack_tenant    => self.passthrough[:openstack_tenant],   # Your tenant id
      :openstack_api_key   => self.passthrough[:openstack_api_key],  # Your OpenStack Password
      :connection_options  => self.passthrough[:connection_options]  # Optional
    }
    @nova = Fog::Compute.new(config)
  end
end
