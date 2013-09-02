require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rouster/deltas'

# TODO better document keys :constrain and :version

class Rouster

  ##
  # validate_file
  #
  # given a filename and a hash of expectations, returns true|false whether file matches expectations
  #
  # parameters
  # * <name> - full file name or relative (to ~vagrant)
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # '/sys/kernel/mm/redhat_transparent_hugepage/enabled', {
  #   :contains => 'never',
  # },
  #
  # '/etc/fstab', {
  #   :contains  => '/dev/fioa*/iodata*xfs',
  #   :constrain => 'is_virtual false' # syntax is '<fact> <expected>', file is only tested if <expected> matches <actual>
  #   :exists    => 'file',
  #   :mode      => '0644'
  # },
  #
  # '/etc/hosts', {
  #   :constrain => ['! is_virtual true', 'is_virtual false'],
  #   :mode      => '0644'
  # }
  #
  # '/etc/nrpe.cfg', {
  #   :ensure   => 'file',
  #   :contains => ['dont_blame_nrpe=1', 'allowed_hosts=' ]
  # }
  #
  # supported keys:
  #   * :exists|:ensure
  #   * :file
  #   * :directory
  #   * :contains (string or array)
  #   * :mode/:permissions
  #   * :owner
  #   * :group
  #   * :constrain
  def validate_file(name, expectations)
    properties = (! expectations[:ensure].nil? and expectations[:ensure].eql?('file')) ?  self.file(name) : self.dir(name)

    expectations[:ensure] ||= 'present'

    if expectations.has_key?(:constrain)
      fact, expectation = expectations[:constrain].split("\s") # TODO add some error checking here
      unless self.meets_constraint?(fact, expectation)
        @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
        true
      end
    end

    results = Hash.new()
    local = nil

    expectations.each do |k,v|

      case k
        when :ensure, :exists
          if properties.nil? and v.match(/absent|false/)
            local = true
          elsif properties.nil?
            local = false
          else
            local = true
          end
        when :file
          if properties.nil?
            local = false
          elsif properties[:file?].true?
            local = true
          else
            false
          end
        when :directory
          if properties.nil?
            local = false
          elsif properties[:directory?].true?
            local = true
          else
            local = false
          end
        when :contains
          v = v.class.eql?(Array) ? v : [v]
          v.each do |regex|
            local = true
            begin
              self.run(sprintf("grep -c '%s' %s", regex, name))
            rescue
              local = false
            end
            next if local.false?
          end
        when :mode, :permissions
          if properties.nil?
            local = false
          elsif v.match(/#{properties[:mode]}/)
            local = true
          else
            local = false
          end
        when :owner
          if properties.nil?
            local = false
          elsif v.match(/#{properties[:owner]}/)
            local = true
          else
            local = false
          end
        when :group
          if properties.nil?
            local = false
          elsif v.match(/#{properties[:group]}/)
            local = true
          else
            local = false
          end
        when :type
          # noop
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results)
    results.find{|k,v| v.false? }.nil?

  end

  ##
  # validate_group
  #
  # given a group and a hash of expectations, returns true|false whether group matches expectations
  #
  # paramaters
  # * <name> - group name
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # 'root', {
  #   # if ensure is not specified, 'present' is implied
  #   :gid => 0,
  #   :user => 'root'
  # }
  # 'sys', {
  #   :ensure => 'present',
  #   :user   => ['root', 'bin', 'daemon']
  # },
  #
  # 'fizz', {
  #   :exists => false
  # },
  #
  # supported keys:
  #  * :exists|:ensure
  #  * :gid
  #  * :user|:users (string or array)
  #  * :constrain
  def validate_group(name, expectations)
    groups = self.get_groups(true)

    if expectations[:ensure].nil? and expectations[:exists].nil?
      expectations[:ensure] = 'present'
    end

    # TODO make this a lambda
    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless self.meets_constraint?(fact, expectation)
          @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
          return true
        end
      end

      expectations.delete(:constrain)
    end

    results = Hash.new()
    local = nil

    expectations.each do |k,v|
      case k
        when :ensure, :exists
          if groups.has_key?(name)
            if v.to_s.match(/absent|false/).nil?
              local = true
            else
              local = false
            end
          else
            local = v.to_s.match(/absent|false/).nil? ? false : true
          end
        when :gid
          local = v.to_s.eql?(groups[name][:gid].to_s)
        when :user, :users
          v = v.class.eql?(Array) ? v : [v]
          v.each do |user|
            local = groups[name][:users].member?(user)
            break unless local.true? # need to make the return value smarter if we want to store data on which user failed
          end
        when :type
          # noop
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  ##
  # validate_package
  #
  # given a package name and a hash of expectations, returns true|false whether package meets expectations
  #
  # parameters
  # * <name> - package name
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # 'perl-Net-SNMP', {
  #   :ensure => 'absent'
  # },
  #
  # 'pixman', {
  #   :ensure => 'present',
  #   :version => '1.0',
  # },
  #
  # 'rrdtool', {
  #   # if ensure is not specified, 'present' is implied
  #   :version => '> 2.1',
  #   :constrain => 'is_virtual false',
  # },
  # supported keys:
  #  * :exists|ensure
  #  * :version  (literal or basic comparison)
  #  * :constrain
  def validate_package(name, expectations)
    packages = self.get_packages(true)

    ## set up some defaults
    expectations[:ensure] ||= 'present'

    if expectations.has_key?(:constrain)
      fact, expectation = expectations[:constrain].split("\s") # TODO add some error checking here
      unless self.meets_constraint?(fact, expectation)
        @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
        true
      end
    end

    results = Hash.new()
    local = nil

    expectations.each do |k,v|
      case k
        when :ensure, :exists
          if packages.has_key?(name)
            if v.to_s.match(/absent|false/).nil?
              local = true
            else
              local = false
            end
          else
            local = false
          end
        when :version
          local = ! v.match(/#{packages[name][:version]}/).nil?
        when :type
          # noop
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    # TODO figure out a good way to allow access to the entire hash, not just boolean -- for now just print at an info level
    @log.info(results)

    # TODO should we implement a fail fast method? at least an option
    results.find{|k,v| v.false? }.nil?
  end

  ##
  # validate_service
  #
  # given a service name and a hash of expectations, returns true|false whether package meets expectations
  #
  # parameters
  # * <name> - service name
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # 'ntp', {
  #   :ensure => 'present',
  #   :state  => 'started'
  # },
  #
  # 'ypbind', {
  #   :state => 'stopped',
  # }
  #
  # supported keys:
  #  * :exists|:ensure
  #  * :state
  #  * :constrain
  def validate_service(name, expectations)
    services = self.get_services(true)

    expectations[:ensure] ||= 'present'

    if expectations.has_key?(:constrain)
      fact, expectation = expectations[:constrain].split("\s") # TODO add some error checking here
      unless self.meets_constraint?(fact, expectation)
        @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
        true
      end
    end

    results = Hash.new()
    local = nil

    expectations.each do |k,v|
      case k
        when :ensure, :exists
          if services.has_key?(name)
            if v.match(/absent|false/)
              local = false
            else
              local = true
            end
          else
            local = false
          end
        when :state
          local = ! v.match(/#{services[name]}/).nil?
        when :type
          # noop
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  ##
  # validate_user
  #
  # given a user name and a hash of expectations, returns true|false whether user meets expectations
  #
  # parameters
  # * <name> - user name
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # 'root' => {
  #   :uid => 0
  # },
  #
  # 'ftp' => {
  #   :exists => true,
  #   :home   => '/var/ftp',
  #   :shell  => 'nologin'
  # },
  #
  # 'developer' => {
  #   :exists    => 'false',
  #   :constrain => 'environment != production'
  # }
  #
  # supported keys:
  #  * :exists|ensure
  #  * :home
  #  * :group
  #  * :shell
  #  * :uid
  #  * :constrain
  def validate_user(name, expectations)
    users = self.get_users(true)

    expectations[:ensure] ||= 'present'

    if expectations.has_key?(:constrain)
      fact, expectation = expectations[:constrain].split("\s") # TODO add some error checking here
      unless self.meets_constraint?(fact, expectation)
        @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
        true
      end
    end

    results = Hash.new()
    local = nil

    expectations.each do |k,v|
      case k
        when :ensure, :exists
          if users.has_key?(name)
            if v.to_s.match(/absent|false/).nil?
              local = true
            else
              local = false
            end
          else
            local = false
          end
        when :group
          v = v.class.eql?(Array) ? v : [v]
          v.each do |group|
            local = is_user_in_group?(name, group)
            break unless local.true?
          end
        when :home
          local = ! v.match(/#{users[:home]}/).nil?
        when :shell
          local = ! v.match(/#{users[:shell]}/).nil?
        when :uid
          local = ! v.match(/#{users[:uid]}/).nil?
        when :type
          # noop
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  ## internal methods
  private

  ##
  # meets_constraint?
  #
  # powers the :constrain value in expectations passed to validate_*
  # gets facts from node, and if fact expectation regex matches actual fact, returns true
  #
  # parameters
  # * <fact> - fact
  # * <expectation>
  # * [cache]
  def meets_constraint?(fact, expectation, cache=true)

    unless self.respond_to?('facter')
      # if we haven't loaded puppet.rb, we won't have access to facts
      @log.warn('using constraints without loading [rouster/puppet] will not work, forcing no-op')
      return false
    end

    facts = self.facter(cache)
    res = expectation.to_s.match(/#{facts[fact]}/)

    res.nil? ? false : true
  end

end
