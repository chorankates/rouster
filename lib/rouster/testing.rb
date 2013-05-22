require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rouster/deltas'

# TODO better document keys :constrain and :version

class Rouster

  def validate_file(name, expectations)
    # '/sys/kernel/mm/redhat_transparent_hugepage/enabled' => {
    #   :contains => 'never',
    # },
    #
    # '/etc/fstab' => {
    #   :contains  => '/dev/fioa*/iodata*xfs',
    #   :constrain => 'is_virtual false' # syntax is '<fact> <expected>', file is only tested if <expected> matches <actual>
    #   :exists    => 'file',
    #   :mode      => '0644'
    # },
    #
    # '/etc/hosts' => {
    #   :constrain => ['! is_virtual true', 'is_virtual false'],
    #   :mode      => '0644'
    # }
    #
    # '/etc/nrpe.cfg' => {
    #   :ensure   => 'file',
    #   :contains => ['dont_blame_nrpe=1', 'allowed_hosts=' ]
    # }
    #
    # supported keys:
    #   :exists|:ensure
    #   :file
    #   :directory
    #   :contains (string or array)
    #   :mode/:permissions
    #   :owner
    #   :group
    #   :constrain
    properties = self.is_file?(name)

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
          local = (! properties.nil? and ! v.match(/absent|false/).nil?)
        when :file
          local = (! properties.nil? and properties[:file?].true?)
        when :directory
          local = (! properties.nil? and properties[:directory?].true?)
        when :contains
          v.each do |regex|
            local = true
            begin
              self.run(sprintf("grep -c '%s' %s", name, regex))
            rescue
              local = false
            end
            next if local.false?
          end
        when :mode, :permissions
          local = (! properties.nil? and ! v.match(/properties[:mode]/).nil?)
        when :owner
          local = (! properties.nil? and ! v.match(/properties[:owner]/).nil?)
        when :group
          local = (! properties.nil? and ! v.match(/properties[:group]/).nil?)
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  def validate_group(name, expectations)
    # 'root' => {
    #   # if ensure is not specified, 'present' is implied
    #   :gid => 0,
    #   :user => 'root'
    # }
    # 'sys' => {
    #   :ensure => 'present',
    #   :user   => ['root', 'bin', 'daemon']
    # },
    #
    # 'fizz' => {
    #   :exists => false
    # },
    #
    # supported keys:
    #  :exists|:ensure
    #  :gid
    #  :user (string or array)
    #  :constrain
    groups = self.get_groups(true)

    expectations[:ensure] ||= 'present'

    # TODO make this a lambda
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
          local = (groups.has_key?(name) and ! v.match(/absent|false/).nil?)
        when :gid
          local = ! v.match(/groups[name][:gid]/).nil?
        when :user
          v.each do |user|
            local = groups[name][:users].has_key?(user)
            next if local.false? # TODO don't fail fast here -- until it's optional
          end
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  def validate_package(name, expectations)
    #'perl-Net-SNMP' => {
    #  :ensure => 'absent'
    #},
    #
    #'pixman' => {
    #  :ensure => 'present',
    #  :version => '1.0',
    #},
    #
    #'rrdtool' => {
    #  # if ensure is not specified, 'present' is implied
    #  :version => '> 2.1',
    #  :constrain => 'is_virtual false',
    #},
    # supported keys:
    #  :exists|ensure
    #  :version  (literal or basic comparison)
    #  :constrain
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
          local = (packages.has_key?(name) and ! v.match(/absent|false/).nil? )
        when :version
          local = ! v.match(/packages[name][:version]/).nil?
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    # TODO figure out a good way to allow access to the entire hash, not just boolean -- for now just print at an info level
    @log.info(results.pretty_print_inspect())

    # TODO should we implement a fail fast method? at least an option
    results.find{|k,v| v.false? }.nil?
  end

  def validate_service(name, expectations)
    # 'ntp' => {
    #   :ensure => 'present',
    #   :state  => 'started'
    # },
    # 'ypbind' => {
    #   :state => 'stopped',
    # }
    #
    # supported keys:
    #  :exists|:ensure
    #  :state
    #  :constrain
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
          local = (services.has_key?(name) and ! v.match(/absent|false/).nil? )
        when :state
          local = ! v.match(/services[name]/).nil?
        else
          raise InternalError.new(sprintf('unknown expectation[%s / %s]', k, v))
      end

      results[k] = local
    end

    @log.info(results.pretty_print_inspect())
    results.find{|k,v| v.false? }.nil?

  end

  def validate_user(name, expectations)
    # 'root' => {
    #   :uid => 0
    # },
    # 'ftp' => {
    #   :exists => true,
    #   :home   => '/var/ftp',
    #   :shell  => 'nologin'
    # },
    # 'developer' => {
    #   :exists    => 'false',
    #   :constrain => 'environment != production'
    # }
    #
    # supported keys:
    #  :exists|ensure
    #  :home
    #  :shell
    #  :uid
    #  :constrain
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
          local = (users.has_key?(name) and ! v.match(/absent|false/).nil? )
        when :home
          local = ! v.match(/users[:home]/).nil?
        when :shell
          local = ! v.match(/users[:shell]/).nil?
        when :uid
          local = ! v.match(/users[:uid]/).nil?
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

  def meets_constraint?(fact, expectation, use_cache=true)

    unless self.respond_to?('facter')
      # if we haven't loaded puppet.rb, we won't have access to facts
      @log.warn('using constraints without loading [rouster/puppet] will not work, forcing no-op')
      false
    end

    if use_cache.false?
      self.facts = self.facter(false)
    end

    res = expectation.match(self.facts[fact])

    res.nil? ? false : true
  end

end
