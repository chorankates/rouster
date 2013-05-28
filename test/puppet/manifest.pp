# == manifest.pp

node default {
  include baseclass
}

node 'app.hsd1.ca.comcast.net' {
  include app_role
}

node 'db' {
  include db_role
}

class baseclass {

  file { '/etc/passwd':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  file { '/tmp/foo':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
  }

  package { ['puppet', 'facter'] :
    ensure => installed,
  }

}

class app_role {

  package { 'rsync':
    ensure => installed,
  }

  user { 'foo':
    ensure  => present,
    groups  => 'bar',
  }

  group { 'bar':
    ensure => present,
    before => User['foo'],
  }

  service { 'snmpd':
    ensure => stopped,
  }

}

class db_role {

  package { 'httpd':
    ensure => installed,
  }

  file { '/tmp/fizzy':
    ensure   => file,
    contents => 'this is a test',
    owner    => 'vagrant',
    group    => 'vagrant',
    mode     => '0444',
  }

  service { 'httpd':
    ensure => running,
  }
}