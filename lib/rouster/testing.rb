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
  #   * :exists|:ensure -- defaults to file if not specified
  #   * :file
  #   * :directory
  #   * :contains (string or array)
  #   * :mode/:permissions
  #   * :size
  #   * :owner
  #   * :group
  #   * :constrain
  def validate_file(name, expectations, cache=false)

    if expectations[:ensure].nil? and expectations[:exists].nil? and expectations[:directory].nil? and expectations[:file?].nil?
      expectations[:ensure] = 'file'
    end

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
          @log.info(sprintf('returning true for expectation [%s], did not meet constraint[%s/%s]', name, fact, expectation))
          return true
        end
      end

      expectations.delete(:constrain)
    end

    properties = (expectations[:ensure].eql?('file')) ?  self.file(name, cache) : self.dir(name, cache)
    results = Hash.new()
    local = nil

    expectations.each do |k,v|

      case k
        when :ensure, :exists
          if properties.nil? and v.to_s.match(/absent|false/)
            local = true
          elsif properties.nil?
            local = false
          else
            case v
              when 'dir', 'directory'
                local = properties[:directory?]
              else
                local = properties[:file?]
            end
          end
        when :file
          if properties.nil?
            if v.to_s.match(/absent|false/)
              local = true
            else
              local = false
            end
          elsif properties[:file?].true?
            local = ! v.to_s.match(/absent|false/)
          else
            false
          end
        when :dir, :directory
          if properties.nil?
            if v.to_s.match(/absent|false/)
              local = true
            else
              local = false
            end
          elsif properties.has_key?(:directory?)
            if properties[:directory?]
              local = v.to_s.match(/absent|false/).nil?
            else
              local = ! v.to_s.match(/absent|false/).nil?
            end
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
          elsif v.to_s.match(/#{properties[:mode].to_s}/)
            local = true
          else
            local = false
          end
        when :size
          if properties.nil?
            local = false
          else
            local = v.to_i.eql?(properties[:size].to_i)
          end
        when :owner
          if properties.nil?
            local = false
          elsif v.to_s.match(/#{properties[:owner].to_s}/)
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

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
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

    @log.info(results)
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

    if expectations[:ensure].nil? and expectations[:exists].nil?
      expectations[:ensure] = 'present'
    end

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
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
          if packages.has_key?(name)
            if v.to_s.match(/absent|false/).nil?
              local = true
            else
              local = false
            end
          else
            local = v.to_s.match(/absent|false/).nil? ? false : true
          end
        when :version
          if v.split("\s").size > 1
            ## generic comparator functionality
            comp, expectation = v.split("\s")
            local = generic_comparator(packages[name], comp, expectation)
          else
            local = ! v.to_s.match(/#{packages[name]}/).nil?
          end
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

  # given a port nnumber and a hash of expectations, returns true|false whether port meets expectations
  #
  # parameters
  # * <number> - port number
  # * <expectations> - hash of expectations, see examples
  #
  # example expectations:
  # '22', {
  #   :ensure => 'active',
  #   :protocol => 'tcp',
  #   :address => '0.0.0.0'
  # },
  #
  # '1234', {
  #   :ensure => 'open',
  #   :address => '*',
  #   :constrain => 'is_virtual false'
  # }
  #
  # supported keys:
  #  * :exists|ensure|state
  #  * :address
  #  * :protocol|proto
  #  * :constrain
  def validate_port(number, expectations)
    number = number.to_s
    ports  = self.get_ports(true)

    if expectations[:ensure].nil? and expectations[:exists].nil? and expectations[:state].nil?
      expectations[:ensure] = 'present'
    end

    if expectations[:protocol].nil? and expectations[:proto].nil?
      expectations[:protocol] = 'tcp'
    elsif ! expectations[:proto].nil?
      expectations[:protocol] = expectations[:proto]
    end

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
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
        when :ensure, :exists, :state
          if v.to_s.match(/absent|false|open/)
            local = ports[expectations[:protocol]][number].nil?
          else
            local = ! ports[expectations[:protocol]][number].nil?
          end
        when :protocol, :proto
          # TODO rewrite this in a less hacky way
          if expectations[:ensure].to_s.match(/absent|false|open/) or expectations[:exists].to_s.match(/absent|false|open/) or expectations[:state].to_s.match(/absent|false|open/)
            local = true
          else
            local = ports[v].has_key?(number)
          end

        when :address
          lr = Array.new
          addresses = ports[expectations[:protocol]][number][:address]
          addresses.each_key do |address|
            lr.push(address.eql?(v.to_s))
          end

          local = ! lr.find{|e| e.true? }.nil? # this feels jankity

        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

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
  #  * :state,:status
  #  * :constrain
  def validate_service(name, expectations)
    services = self.get_services(true)

    if expectations[:ensure].nil? and expectations[:exists].nil?
      expectations[:ensure] = 'present'
    end

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
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
          if services.has_key?(name)
            if v.to_s.match(/absent|false/)
              local = false
            else
              local = true
            end
          else
            local = v.to_s.match(/absent|false/).nil? ? false : true
          end
        when :state, :status
          local = ! v.match(/#{services[name]}/).nil?
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
  #  * :gid
  #  * :constrain
  def validate_user(name, expectations)
    users = self.get_users(true)

    if expectations[:ensure].nil? and expectations[:exists].nil?
      expectations[:ensure] = 'present'
    end

    if expectations.has_key?(:constrain)
      expectations[:constrain] = expectations[:constrain].class.eql?(Array) ? expectations[:constrain] : [expectations[:constrain]]

      expectations[:constrain].each do |constraint|
        fact, expectation = constraint.split("\s")
        unless meets_constraint?(fact, expectation)
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
          if users.has_key?(name)
            if v.to_s.match(/absent|false/).nil?
              local = true
            else
              local = false
            end
          else
            local = v.to_s.match(/absent|false/).nil? ? false : true
          end
        when :group
          v = v.class.eql?(Array) ? v : [v]
          v.each do |group|
            local = is_user_in_group?(name, group)
            break unless local.true?
          end
        when :gid
          local = v.to_i.eql?(users[name][:gid].to_i)
        when :home
          local = ! v.match(/#{users[name][:home]}/).nil?
        when :home_exists
          local = ! v.to_s.match(/#{users[name][:home_exists].to_s}/).nil?
        when :shell
          local = ! v.match(/#{users[name][:shell]}/).nil?
        when :uid
          local = v.to_i.eql?(users[name][:uid].to_i)
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

    expectation = expectation.to_s
    facts = self.facter(cache)

    res = nil
    if expectation.split("\s").size > 1
      ## generic comparator functionality
      comp, expectation = expectation.split("\s")

      res = generic_comparator(facts[fact], comp, expectation)

    else
      res = ! expectation.match(/#{facts[fact]}/).nil?
      @log.debug(sprintf('meets_constraint?(%s, %s): %s', fact, expectation, res.nil?))
    end

    res
  end

  ##
  # generic_comparator
  #
  # powers the 3 argument form of constraint (i.e. 'is_virtual != true', '<package_version> > 3.0', etc)
  #
  # should really be an eval{} of some sort (or would be in the perl world)
  #
  # parameters
  # * <comparand1> - left side of the comparison
  # * <comparator> - comparison to make
  # * <comparand2> - right side of the comparison
  def generic_comparator(comparand1, comparator, comparand2)

    # TODO rewrite this as an eval so we don't have to support everything..
    case comparator
      when '!='
        # ugh
        if comparand1.to_s.match(/\d/) or comparand2.to_s.match(/\d/)
          res = ! comparand1.to_i.eql?(comparand2.to_i)
        else
          res = ! comparand1.eql?(comparand2)
        end
      when '<'
        res = comparand1.to_i < comparand2.to_i
      when '<='
        res = comparand1.to_i <= comparand2.to_i
      when '>'
        res = comparand1.to_i > comparand2.to_i
      when '>='
        res = comparand1.to_i >= comparand2.to_i
      when '=='
        # ugh ugh
        if comparand1.to_s.match(/\d/) or comparand2.to_s.match(/\d/)
          res = comparand1.to_i.eql?(comparand2.to_i)
        else
          res = comparand1.eql?(comparand2)
        end
      else
        raise NotImplementedError.new(sprintf('unknown comparator[%s]', comparator))
    end



    res
  end

end
