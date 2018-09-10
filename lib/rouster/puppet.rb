require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'json'
require 'net/https'
require 'socket'
require 'uri'

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

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:facter]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [facter] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:facter]), self.cache_timeout))
        self.facts = nil
      else
        @logger.debug(sprintf('using cached [facter] from [%s]', self.cache[:facter]))
        return self.facts
      end

    end

    cmd = 'facter -y' # getting YAML output to handle differences in facter 1.x and 3.x default output
    cmd << ' -p' if custom_facts.true?

    raw = self.run(cmd)
    res = Hash.new

    begin
      res = YAML.parse(raw)
    rescue => e
      raise ExternalError.new(sprintf('unable to parse facter output as YAML[%s], cmd[%s], raw[%s]', e.message, cmd, raw))
    end

    if cache.true?
      @logger.debug(sprintf('caching [facter] at [%s]', Time.now.asctime))
      self.facts = res
      self.cache[:facter] = Time.now.to_i
    end

    res
  end

  ##
  # did_exec_fire?
  #
  # given the name of an Exec resource, parse the output from the most recent puppet run
  # and return true/false based on whether the exec in question was fired
  def did_exec_fire?(resource_name, puppet_run = self.last_puppet_run)
    # Notice: /Stage[main]//Exec[foo]/returns: executed successfully
    # Error: /Stage[main]//Exec[bar]/returns: change from notrun to 0 failed: Could not find command '/bin/bar'
    matchers = [
      'Notice: /Stage\[.*\]//Exec\[%s\]/returns: executed successfully',
      'Error: /Stage\[.*\]//Exec\[%s\]/returns: change from notrun to 0 failed'
    ]

    matchers.each do |m|
      matcher = sprintf(m, resource_name)
      return true if puppet_run.match(matcher)
    end

    false
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
    facts        = facts.nil? ? self.facter() : facts

    %w(fqdn hostname operatingsystem operatingsystemrelease osfamily rubyversion).each do |required|
      raise ArgumentError.new(sprintf('missing required fact[%s]', required)) unless facts.has_key?(required)
    end

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
  # * [input] - string to look at, defaults to self.get_ssh_stdout.to_s + self.get_ssh_stderr.to_s
  def get_puppet_errors(input=nil)
    str       = input.nil? ? self.get_ssh_stdout.to_s + self.get_ssh_stderr.to_s : input
    errors    = nil
    errors_27 = str.scan(/35merr:.*/)
    errors_30 = str.scan(/Error:.*/)

    # TODO this is a little less than efficient, don't scan for 3.0 if you found 2.7
    if errors_27.size > 0
      errors = errors_27
    else
      errors = errors_30
    end

    errors.empty? ? nil : errors
  end

  ##
  # get_puppet_notices
  #
  # parses input for puppet notices, returns array of strings
  #
  # parameters
  # * [input] - string to look at, defaults to self.get_ssh_stdout.to_s + self.get_ssh_stderr.to_s
  def get_puppet_notices(input=nil)
    str        = input.nil? ? self.get_ssh_stdout.to_s + self.get_ssh_stderr.to_s : input
    notices    = nil
    notices_27 = str.scan(/36mnotice:.*/) # not sure when this stopped working
    notices_30 = str.scan(/Notice:.*/)

    # TODO this is a little less than efficient, don't scan for 3.0 if you found 2.7
    if notices_27.size > 0
      notices = notices_27
    else
      notices = notices_30
    end

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
  # * <key>     - hiera key to look up
  # * [facts]   - hash of facts to be used in hiera lookup (technically optional, but most useful hiera lookups are based on facts)
  # * [config]  - path to hiera configuration -- this is only optional if you have a hiera.yaml file in ~/vagrant, default option is correct for most puppet installations
  # * [options] - any additional parameters to be passed to hiera directly
  #
  # note
  # * if no facts are provided, facter() will be called - to really run hiera without facts, send an empty hash
  # * this method is mostly useful on your puppet master, as your agents won't likely have /etc/puppet/hiera.yaml - to get data on another node, specify it's facts and call hiera on your ppm
  def hiera(key, facts=nil, config='/etc/puppet/hiera.yaml', options=nil)
    # TODO implement caching? where do we keep it? self.hiera{}? or self.deltas{} -- leaning towards #1

    cmd = 'hiera'

    if facts.nil?
      @logger.info('no facts provided, calling facter() automatically')
      facts = self.facter()
    end

    if facts.keys.size > 0
      scope_file = sprintf('/tmp/rouster-hiera_scope.%s.%s.json', $$, Time.now.to_i)

      File.write(scope_file, facts.to_json)
      self.put(scope_file, scope_file)
      File.delete(scope_file)

      cmd << sprintf(' -j %s', scope_file)
    end

    cmd << sprintf(' -c %s', config) unless config.nil?
    cmd << sprintf(' %s', options) unless options.nil?
    cmd << sprintf(' %s', key)

    raw = self.run(cmd)

    begin
      JSON.parse(raw)
    rescue => e
      raise ExternalError.new(sprintf('unable to parse hiera output as JSON[%s], cmd[%s], raw[%s]', e.message, cmd, raw))
    end

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

  # TODO: come up with better method names here.. remove_existing_certs() and remove_specific_cert() are not very descriptive

  ##
  # remove_existing_certs
  #
  # ... removes existing certificates - really only useful when called on a puppetmaster
  # useful in testing environments where you want to destroy/rebuild agents without rebuilding the puppetmaster every time (think autosign)
  #
  # parameters
  # * <puppetmaster> - string/partial regex of certificate names to keep
  def remove_existing_certs (except)
    except = except.kind_of?(Array) ? except : [except] # need to move from <>.class.eql? to <>.kind_of? in a number of places
    hosts  = Array.new()

    res = self.run('puppet cert list --all')

    # TODO refactor this away from the hacky_break
    res.each_line do |line|
      hacky_break = false

      except.each do |exception|
        next if hacky_break
        hacky_break = line.match(/#{exception}/)
      end

      next if hacky_break

      host = $1 if line.match(/^\+\s"(.*?)"/)

      hosts.push(host) unless host.nil? # only want to clear signed certs
    end

    hosts.each do |host|
      self.run(sprintf('puppet cert --clean %s', host))
    end

  end

  ##
  # remove_specific_cert
  #
  # ... removes a specific (or several specific) certificates, effectively the reverse of remove_existing_certs() - and again, really only useful when called on a puppet master
  def remove_specific_cert (targets)
    targets = targets.kind_of?(Array) ? targets : [targets]
    hosts = Array.new()

    res = self.run('puppet cert list --all')

    res.each_line do |line|
      hacky_break = true

      targets.each do |target|
        next unless hacky_break
        hacky_break = line.match(/#{target}/)
      end

      next unless hacky_break

      host = $1 if line.match(/^\+\s"(.*?)"/)
      hosts.push(host) unless host.nil?

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
  #  * master - runs 'puppet agent -t'
  #    * supported options
  #      * expected_exitcode - string/integer/array of acceptable exit code(s)
  #      * configtimeout - string/integer of the acceptable configtimeout value
  #      * environment - string of the environment to use
  #      * certname - string of the certname to use in place of the host fqdn
  #      * pluginsync - bool value if pluginsync should be used
  #      * server - string value of the puppetmasters fqdn / ip
  #      * additional_options - string of various options that would be passed to puppet
  #  * masterless - runs 'puppet apply <options>' after determining version of puppet running and adjusting arguments
  #    * supported options
  #      * expected_exitcode - string/integer/array of acceptable exit code(s)
  #      * hiera_config - path to hiera configuration -- only supported by Puppet 3.0+
  #      * manifest_file - string/array of strings of paths to manifest(s) to apply
  #      * manifest_dir - string/array of strings of directories containing manifest(s) to apply - is recursive
  #      * module_dir - path to module directory -- currently a required parameter, is this correct?
  #      * environment - string of the environment to use (default: production)
  #      * certname - string of the certname to use in place of the host fqdn (default: unused)
  #      * pluginsync - bool value if pluginsync should be used (default: true)
  #      * additional_options - string of various options that would be passed to puppet
  #
  # parameters
  # * [mode] - method to run puppet, defaults to 'master'
  # * [opts] - hash of additional options
  def run_puppet(mode='master', passed_opts={})

    if mode.eql?('master')
      opts = {
        :expected_exitcode  => 0,
        :configtimeout      => nil,
        :environment        => nil,
        :certname           => nil,
        :server             => nil,
        :pluginsync         => false,
        :additional_options => nil
      }.merge!(passed_opts)

      cmd = 'puppet agent -t'
      cmd << sprintf(' --configtimeout %s', opts[:configtimeout]) unless opts[:configtimeout].nil?
      cmd << sprintf(' --environment %s', opts[:environment]) unless opts[:environment].nil?
      cmd << sprintf(' --certname %s', opts[:certname]) unless opts[:certname].nil?
      cmd << sprintf(' --server %s', opts[:server]) unless opts[:server].nil?
      cmd << ' --pluginsync' if opts[:pluginsync]
      cmd << opts[:additional_options] unless opts[:additional_options].nil?

      self.run(cmd, opts[:expected_exitcode])

    elsif mode.eql?('masterless')
      opts = {
        :expected_exitcode  => 2,
        :hiera_config       => nil,
        :manifest_file      => nil, # can be a string or array, will 'puppet apply' each
        :manifest_dir       => nil, # can be a string or array, will 'puppet apply' each module in the dir (recursively)
        :module_dir         => nil,
        :environment        => nil,
        :certname           => nil,
        :pluginsync         => false,
        :additional_options => nil
      }.merge!(passed_opts)

      ## validate arguments -- can do better here (:manifest_dir, :manifest_file)
      puppet_version = self.get_puppet_version() # hiera_config specification is only supported in >3.0, but NOT required anywhere

      if opts[:hiera_config]
        if puppet_version > '3.0'
          raise InternalError.new(sprintf('invalid hiera config specified[%s]', opts[:hiera_config])) unless self.is_file?(opts[:hiera_config])
        else
          @logger.error(sprintf('puppet version[%s] does not support --hiera_config, ignoring', puppet_version))
        end
      end

      if opts[:module_dir]
        raise InternalError.new(sprintf('invalid module dir specified[%s]', opts[:module_dir])) unless self.is_dir?(opts[:module_dir])
      end

      if opts[:manifest_file]
        opts[:manifest_file] = opts[:manifest_file].class.eql?(Array) ? opts[:manifest_file] : [opts[:manifest_file]]
        opts[:manifest_file].each do |file|
          raise InternalError.new(sprintf('invalid manifest file specified[%s]', file)) unless self.is_file?(file)

          cmd = 'puppet apply --detailed-exitcodes'
          cmd << sprintf(' --modulepath=%s', opts[:module_dir]) unless opts[:module_dir].nil?
          cmd << sprintf(' --hiera_config=%s', opts[:hiera_config]) unless opts[:hiera_config].nil? or puppet_version < '3.0'
          cmd << sprintf(' --environment %s', opts[:environment]) unless opts[:environment].nil?
          cmd << sprintf(' --certname %s', opts[:certname]) unless opts[:certname].nil?
          cmd << ' --pluginsync' if opts[:pluginsync]
          cmd << sprintf(' %s', opts[:additional_options]) unless opts[:additional_options].nil?
          cmd << sprintf(' %s', file)

          self.last_puppet_run = self.run(cmd, opts[:expected_exitcode])
        end
      end

      if opts[:manifest_dir]
        opts[:manifest_dir] = opts[:manifest_dir].class.eql?(Array) ? opts[:manifest_dir] : [opts[:manifest_dir]]
        opts[:manifest_dir].each do |dir|
          raise InternalError.new(sprintf('invalid manifest dir specified[%s]', dir)) unless self.is_dir?(dir)

          manifests = self.files(dir, '*.pp', true)

          manifests.each do |m|

            cmd = 'puppet apply --detailed-exitcodes'
            cmd << sprintf(' --modulepath=%s', opts[:module_dir]) unless opts[:module_dir].nil?
            cmd << sprintf(' --hiera_config=%s', opts[:hiera_config]) unless opts[:hiera_config].nil? or puppet_version < '3.0'
            cmd << sprintf(' --environment %s', opts[:environment]) unless opts[:environment].nil?
            cmd << sprintf(' --certname %s', opts[:certname]) unless opts[:certname].nil?
            cmd << ' --pluginsync' if opts[:pluginsync]
            cmd << sprintf(' %s', opts[:additional_options]) unless opts[:additional_options].nil?
            cmd << sprintf(' %s', m)

            self.last_puppet_run = self.run(cmd, opts[:expected_exitcode])
          end

        end
      end

    else
      raise InternalError.new(sprintf('unknown mode [%s]', mode))
    end


  end

end
