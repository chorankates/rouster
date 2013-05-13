require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rouster/deltas'

# TODO better document keys :constrain and :version

class Rouster

  def validate_file(filename, options)
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

  def validate_group(group, options)
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

  def validate_package(package, options)
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
    raise NotImplementedError.new()
  end

  def validate_service(service, options)
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

  def validate_user(user, options)
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

end
