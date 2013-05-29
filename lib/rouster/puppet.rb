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

  def get_catalog(hostname=nil)
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

    raw_resources = catalog['data']['resources']

    raw_resources.each do |r|

      # directory resource

      # file resource
      # {"exported"=>false,
      # "file"=>"/etc/puppet/modules/p4users/manifests/init.pp",
      # "parameters"=>{"owner"=>"root", "group"=>"root",
      # "ensure"=>"present", "source"=>"puppet:///modules/p4users/p4"},
      # "line"=>34, "type"=>"File", "title"=>"/usr/local/bin/p4",
      # "tags"=>["file", "class", "p4users", "baseclass", "node", "default"]}

      # group resource
      # package resource
      # service resource
      # user resource

      type = r['type']
      case type
        when 'File'
          name = r['title']
          resources[name] = Hash.new()


          resources[name][:type]      = :file
          resources[name][:directory] = false
          resources[name][:ensure]    = r['ensure'] ||= 'present'
          resources[name][:file]      = true
          resources[name][:group]     = r['parameters'].has_key?('group') ? r['parameters']['group'] : nil
          resources[name][:mode]      = r['parameters'].has_key?('mode')  ? r['parameters']['mode']  : nil # unsure of this one
          resources[name][:owner]     = r['parameters'].has_key?('owner') ? r['parameters']['owner'] : nil
          resources[name][:contains]  = r.has_key?('contents') ? r['contents'] : nil # unsure of this one

        when 'Class'
          classes.push(r['title'])

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
          resources[name][:version] = r['parameters'].has_key?('version') ? r['parameters']['version'] : nil

        when 'Service'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type] = :service
          resources[name][:ensure] = r['ensure'] ||= 'present'

          #  :state

        when 'User'
          name = r['title']
          resources[name] = Hash.new()

          resources[name][:type]   = :user
          resources[name][:ensure] = r['ensure'] ||= 'present'
          resources[name][:home]   = r['parameters'].has_key?('home')  ? r['parameters']['home']   : nil
          resources[name][:gid]    = r['parameters'].has_key?('gid')   ? r['parameters']['gid']    : nil
          resources[name][:group]  = r['parameters'].has_key?('group') ? r['parameters']['groups'] : nil # is this already an array?
          resources[name][:shell]  = r['parameters'].has_key?('shell') ? r['parameters']['shell']  : nil
          resources[name][:uid]    = r['parameters'].has_key?('uid')   ? r['parameters']['uid']    : nil


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