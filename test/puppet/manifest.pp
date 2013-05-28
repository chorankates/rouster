# == manifest.pp

node default {
  include baseclass
}

node 'app' {
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
    group   => 'bar',
    require => Group['bar'],
  }

  group { 'bar':
    ensure => present,
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
}