require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'json'
require 'net/https'
require 'socket'
require 'uri'

# TODO use @cache_timeout to invalidate data cached here

class Rouster

  ##
  # facter
  #
  # runs facter, returns parsed hash of { fact1 => value1, factN => valueN }
  #
  # parameters
  # * [cache] - whether to store/return cached facter data, if available
  # * [custom_facts] - whether to include custom facts in return (uses -p argument)
  def facter(cache=true, custom_facts=true)
    if cache.true? and ! self.facts.nil?
      return self.facts
    end

    raw  = self.run(sprintf('facter %s', custom_facts.true? ? '-p' : ''))
    res  = Hash.new()

    raw.split("\n").each do |line|
      next unless line.match(/(\S*?)\s\=\>\s(.*)/)
      res[$1] = $2
    end

    if cache.true?
      self.facts = res
    end

    res
  end

  ##
  # get_catalog
  #
  # not completely implemented method to get a compiled catalog about a node (based on its facts) from a puppetmaster
  #
  # original implementation used the catalog face, which does not actually work. switched to an API call, but still need to convert facts into PSON
  #
  # parameters
  # * [hostname] - hostname of node to return catalog for, if not specified, will use `hostname --fqdn`
  # * [puppetmaster] - hostname of puppetmaster to use in API call, defaults to 'puppet'
  # * [facts] - hash of facts to pass to puppetmaster
  # * [puppetmaster_port] - port to talk to the puppetmaster on, defaults to 8140
  def get_catalog(hostname=nil, puppetmaster=nil, facts=nil, puppetmaster_port=8140)
    # post https://<puppetmaster>/catalog/<node>?facts_format=pson&facts=<pson URL encoded> == ht to patrick@puppetlabs
    certname     = hostname.nil? ? self.run('hostname --fqdn').chomp : hostname
    puppetmaster = puppetmaster.nil? ? 'puppet' : puppetmaster
    facts        = facts.nil? ? self.facter() : facts # TODO check for presence of certain 'required' facts/datatype?

    raise InternalError.new('need to finish conversion of facts to PSON')
    facts.to_pson # this does not work, but needs to

    json = nil
    url  = sprintf('https://%s:%s/catalog/%s?facts_format=pson&facts=%s', puppetmaster, puppetmaster_port, certname, facts)
    uri  = URI.parse(url)

    begin
      res  = Net::HTTP.get(uri)
      json = res.to_json
    rescue => e
      raise ExternalError.new("calling[#{url}] led to exception[#{e}")
    end

    json
  end

  ##
  # get_puppet_errors
  #
  # parses input for puppet errors, returns array of strings
  #
  # parameters
  # * [input] - string to look at, defaults to self.get_output()
  def get_puppet_errors(input=nil)
    str    = input.nil? ? self.get_output() : input
    errors = str.scan(/35merr:.*/)

    errors.empty? ? nil : errors
  end

  ##
  # get_puppet_notices
  #
  # parses input for puppet notices, returns array of strings
  #
  # parameters
  # * [input] - string to look at, defaults to self.get_output()
  def get_puppet_notices(input=nil)
    str     = input.nil? ? self.get_output() : input
    notices = str.scan(/36mnotice:.*/)

    notices.empty? ? nil : notices
  end

  ##
  # get_puppet_version
  #
  # executes `puppet --version` and returns parsed version string or nil
  def get_puppet_version
    version   = nil
    installed = self.is_in_path?('puppet')

    if installed
      raw = self.run('puppet --version')
      version = raw.match(/([\d\.]*)\s/) ? $1 : nil
    else
      version = nil
    end

    version
  end

  ##
  # hiera
  #
  # returns hiera results from self
  #
  # parameters
  # * <key> - hiera key to look up
  # * [config] - path to hiera configuration -- this is only optional if you have a hiera.yaml file in ~/vagrant
  def hiera(key, config=nil)

    # TODO implement this
    raise NotImplementedError.new()

  end

  ##
  # parse_catalog
  #
  # looks at the ['data']['resources'] keys in catalog for Files, Groups, Packages, Services and Users, returns hash of expectations compatible with validate_*
  #
  # this is a very lightly tested implementation, please open issues as necessary
  #
  # parameters
  # * <catalog> - JSON string or Hash representation of catalog, typically from get_catalog()
  def parse_catalog(catalog)
    classes   = nil
    resources = nil
    results   = Hash.new()

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

  ##
  # remove_existing_certs
  #
  # ... removes existing certificates - really only useful when called on a puppetmaster
  # useful in testing environments where you want to destroy/rebuild agents without rebuilding the puppetmaster every time (think autosign)
  #
  # parameters
  # * <puppetmaster> - string/partial regex of certificate names to keep
  def remove_existing_certs (puppetmaster)
    hosts = Array.new()

    res = self.run('puppet cert list --all')

    res.each_line do |line|
      next if line.match(/#{puppetmaster}/)
      host = $1 if line.match(/^\+\s"(.*?)"/)

      hosts.push(host)
    end

    hosts.each do |host|
      self.run(sprintf('puppet cert --clean %s', host))
    end

  end

  ##
  # run_puppet
  #
  # ... runs puppet on self, returns nothing
  #
  # currently supports 2 methods of running puppet:
  #  * master - runs '/sbin/service puppet once -t'
  #    * supported options
  #      * expected_exitcode - string/integer/array of acceptable exit code(s)
  #  * masterless - runs 'puppet apply <options>' after determining version of puppet running and adjusting arguments
  #    * supported options
  #      * expected_exitcode - string/integer/array of acceptable exit code(s)
  #      * hiera_config - path to hiera configuration -- only supported by Puppet 3.0+
  #      * manifest_file - string/array of strings of paths to manifest(s) to apply
  #      * manifest_dir - string/array of strings of directories containing manifest(s) to apply - is recursive
  #      * module_dir - path to module directory -- currently a required parameter, is this correct?
  #
  # parameters
  # * [mode] - method to run puppet, defaults to 'master'
  # * [opts] - hash of additional options
  def run_puppet(mode='master', passed_opts=nil)

    if mode.eql?('master')
      opts = {
        :expected_exitcode => 0
      }.merge!(passed_opts)

      self.run('/sbin/service puppet once -t', opts[:expected_exitcode])

    elsif mode.eql?('masterless')
      opts = {
        :expected_exitcode => 2,
        :hiera_config      => nil,
        :manifest_file     => nil, # can be a string or array, will 'puppet apply' each
        :manifest_dir      => nil, # can be a string or array, will 'puppet apply' each module in the dir (recursively)
        :module_dir        => nil
      }.merge!(passed_opts)

      ## validate required arguments
      raise InternalError.new(sprintf('invalid hiera config specified[%s]', opts[:hiera_config])) unless self.is_file?(opts[:hiera_config])
      raise InternalError.new(sprintf('invalid module dir specified[%s]', opts[:module_dir])) unless self.is_dir?(opts[:module_dir])

      puppet_version = self.get_puppet_version() # hiera_config specification is only supported in >3.0

      if opts[:manifest_file]
        opts[:manifest_file] = opts[:manifest_file].class.eql?(Array) ? opts[:manifest_file] : [opts[:manifest_file]]
        opts[:manifest_file].each do |file|
          raise InternalError.new(sprintf('invalid manifest file specified[%s]', file)) unless self.is_file?(file)

          self.run(sprintf('puppet apply %s --modulepath=%s %s', (puppet_version > '3.0') ? "--hiera_config=#{opts[:hiera_config]}" : '', opts[:module_dir], file), opts[:expected_exitcode])

        end
      end

      if opts[:manifest_dir]
        opts[:manifest_dir] = opts[:manifest_dir].class.eql?(Array) ? opts[:manifest_dir] : [opts[:manifest_dir]]
        opts[:manifest_dir].each do |dir|
          raise InternalError.new(sprintf('invalid manifest dir specified[%s]', dir)) unless self.is_dir?(dir)

          manifests = self.files(dir, '*.pp', true)

          manifests.each do |m|

            self.run(sprintf('puppet apply %s --modulepath=%s %s', (puppet_version > '3.0') ? "--hiera_config=#{opts[:hiera_config]}" : '', opts[:module_dir], m), opts[:expected_exitcode])

          end

        end
      end

    else
      raise InternalError.new(sprintf('unknown mode [%s]', mode))
    end


  end

end