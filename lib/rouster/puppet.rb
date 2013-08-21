require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'json'
require 'socket'

# == rouster/puppet
# an extension to Rouster containing Puppet related code:
#  * facter()
#  * get_catalog()
#  * get_puppet_errors()
#  * get_puppet_notices()
#  * parse_catalog()
#  * remove_existing_certs()
#  * run_puppet()
#

class Rouster

  def facter(cache=true, custom_facts=true)
    if cache.true? and ! self.facts.nil?
      self.facts
    end

    json = nil
    res  = self.run(sprintf('facter %s', custom_facts.true? ? '-p' : ''))

    begin
      json = JSON.parse(res)
    rescue
      raise InternalError.new(sprintf('unable to parse[%s] as JSON', res))
    end

    if cache.true?
      self.facts = res
    end

    json
  end

  def get_catalog(hostname=nil)
    certname = hostname.nil? ? self.run('hostname --fqdn').chomp : hostname

    json = nil
    res  = self.run(sprintf('puppet catalog find %s', certname))

    begin
      json = JSON.parse(res)
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

    unless catalog.has_key?('data') and catalog['data'].has_key?('resources')
      raise InternalError.new(sprintf('catalog does not contain a resources key[%s]', catalog))
    end

    raw_resources = catalog['data']['resources']

    raw_resources.each do |r|
      # samples of eacb type of resource is available at
      # https://github.com/chorankates/rouster/issues/20#issuecomment-18635576
      #
      # we can do a lot better here
      type = r['type']
      case type
        when 'Class'
          classes.push(r['title'])
        when 'File'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]      = :file
          resources[name][:directory] = false
          resources[name][:ensure]    = r['ensure'] ||= 'present'
          resources[name][:file]      = true
          resources[name][:group]     = r['parameters'].has_key?('group') ? r['parameters']['group'] : nil
          resources[name][:mode]      = r['parameters'].has_key?('mode')  ? r['parameters']['mode']  : nil
          resources[name][:owner]     = r['parameters'].has_key?('owner') ? r['parameters']['owner'] : nil
          resources[name][:contains]  = r.has_key?('content') ? r['content'] : nil

        when 'Group'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]   = :group
          resources[name][:ensure] = r['ensure'] ||= 'present'
          resources[name][:gid]    = r['parameters'].has_key?('gid') ? r['parameters']['gid'] : nil

        when 'Package'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]    = :package
          resources[name][:ensure]  = r['ensure'] ||= 'present'
          resources[name][:version] = r['ensure'] =~ /\d/ ? r['ensure'] : nil

        when 'Service'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]   = :service
          resources[name][:ensure] = r['ensure'] ||= 'present'
          resources[name][:state]  = r['ensure']

        when 'User'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]   = :user
          resources[name][:ensure] = r['ensure'] ||= 'present'
          resources[name][:home]   = r['parameters'].has_key?('home')   ? r['parameters']['home']   : nil
          resources[name][:gid]    = r['parameters'].has_key?('gid')    ? r['parameters']['gid']    : nil
          resources[name][:group]  = r['parameters'].has_key?('groups') ? r['parameters']['groups'] : nil
          resources[name][:shell]  = r['parameters'].has_key?('shell')  ? r['parameters']['shell']  : nil
          resources[name][:uid]    = r['parameters'].has_key?('uid')    ? r['parameters']['uid']    : nil

        else
          raise NotImplementedError.new(sprintf('parsing support for [%s] is incomplete', type))
      end

    end

    # remove all nil references
    # TODO make this more rubyish
    resources.each_key do |name|
      resources[name].each_pair do |k,v|
        unless v
          resources[name].delete(k)
        end
      end
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

  def run_puppet(expected_exitcode=0)
    self.run('/sbin/service puppet once -t', expected_exitcode)
  end

end