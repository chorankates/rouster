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
    #   :false
    #   :contains (string or array)
    #   :mode/:permissions
    #   :owner
    #   :group
    #   :constrain
    raise NotImplementedError.new()
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
    raise NotImplementedError.new()
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
        when :ensure, :exists:
          local = (packages.has_key?(name) and v.match(/absent/))
        when :version:
          local = v.match(/packages[name]['version']/)
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
    raise NotImplementedError.new()
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
    raise NotImplementedError.new()
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
