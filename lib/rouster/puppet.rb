require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'json'
require 'socket'

class Rouster

  def facter(use_cache=true, custom_facts=true)
    if use_cache.true? and ! self.facts.nil?
      self.facts
    end

    json = nil
    res  = self.run(sprintf('facter %s', custom_facts.true? ? '-p' : ''))

    begin
      json = res.to_json
    rescue
      raise InternalError.new(sprintf('unable to parse[%s] as JSON', res))
    end

    if use_cache.true?
      self.facts = res
    end

    json
  end

  def get_catalog(hostname)
    certname = hostname.nil? ? self.run('hostname --fqdn') : hostname

    json = nil
    res  = self.run(sprintf('puppet catalog find %s', certname))

    begin
      json = res.to_json
    rescue
      raise InternalError.new(sprintf('unable to parse[%s] as JSON', res))
    end

    json
  end

  def get_puppet_errors(input = nil)
    str    = input.nil? ? self.get_output() : input
    errors = str.scan(/35merr:.*/)

    errors.empty? ? nil : errors
  end

  def get_puppet_notices(input = nil)
    str     = input.nil? ? self.get_output() : input
    notices = str.scan(/36mnotice:.*/)

    notices.empty? ? nil : notices
  end

  def parse_catalog(catalog)
    classes   = nil
    resources = nil
    results   = Hash.new()

    # support either JSON or already parsed Hash
    if catalog.is_a?(String)
      begin
        JSON.parse!(catalog)
      rescue
        raise InternalError.new(sprintf('unable to parse catalog[%s] as JSON', catalog))
      end
    end

    unless catalog.has_key?('data') and catalog['data'].has_key?('classes')
      raise InternalError.new(sprintf('catalog does not contain a classes key[%s]', catalog))
    end

    classes = catalog['data']['classes']

    unless catalog.has_key?('data') and catalog['data'].has_key?('resources')
      raise InternalError.new(sprintf('catalog does not contain a resources key[%s]', catalog))
    end

    resources = catalog['data']['resources']

    resources.each do |r|
      # first array element -- looks like this element comes before each set of resources for the class in question
      # {"exported"=>false, "type"=>"Class", "title"=>"P4users", "tags"=>["class", "p4users", "baseclass", "node", "default"]}

      # file resource
      # {"exported"=>false, "file"=>"/etc/puppet/modules/p4users/manifests/init.pp", "parameters"=>{"owner"=>"root", "group"=>"root", "ensure"=>"present", "source"=>"puppet:///modules/p4users/p4"}, "line"=>34, "type"=>"File", "title"=>"/usr/local/bin/p4", "tags"=>["file", "class", "p4users", "baseclass", "node", "default"]}

      # user resource

      # group resource

      # service resource

      # stage resource
      # {"exported"=>false, "parameters"=>{"name"=>"main"}, "type"=>"Stage", "title"=>"main", "tags"=>["stage"]}

      # node resource
      # {"exported"=>false, "type"=>"Node", "title"=>"default", "tags"=>["node", "default", "class"]}

      # file resource with a stage
      # {"exported"=>false, "file"=>"/etc/puppet/manifests/templates.pp", "parameters"=>{"before"=>"Stage[main]"}, "line"=>18, "type"=>"Stage", "title"=>"first", "tags"=>["stage", "first", "class"]}

    end

    results[:classes]   = classes
    results[:resources] = resources

    results
  end

  def remove_existing_certs (puppetmaster)
    # removes all certificates that a puppetmaster knows about aside from it's own (useful in testing where autosign is in use)
    # really only useful if called from a puppet master
    hosts = Array.new()

    res = self.run('puppet cert --list --all')

    res.each_line do |line|
      next if line.match(/#{puppetmaster}/)
      host = $1 if line.match(/^\+\s"(.*?)"/)

      hosts.push(host)
    end

    hosts.each do |host|
      self.run(sprintf('puppet cert --clean %s', host))
    end

  end

  def run_puppet
    self.run('/sbin/service puppet once -t')
  end

end