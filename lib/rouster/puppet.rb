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

  # TODO we should be able to run this without upping the box in question --
  # just need to be able to talk to the same puppetmaster, which means we should 'require puppet' instead of shelling out

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

  # TODO parse into a hash that can be passed to the validate_* methods
  def parse_catalog(catalog)
    resources = nil

    # support either JSON or already parsed Hash
    if catalog.is_a?(String)
      begin
        JSON.parse!(catalog)
      rescue
        raise InternalError.new(sprintf('unable to parse catalog[%s] as JSON', catalog))
      end
    end

    unless catalog.has_key?('data') and catalog['data'].has_key?('resources')
      raise InternalError.new(sprintf('catalog does not contain a resources key[%s]', catalog))
    end

    resources = catalog['data']['resources']

  end

  def run_puppet
    # TODO should we make this more flexible?
    self.run('/sbin/service puppet once -t')
  end

end