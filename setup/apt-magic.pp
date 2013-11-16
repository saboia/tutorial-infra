# Make sure apt-get -y update runs before anything else.
stage { 'preinstall': before => Stage['main'] }

class apt_get_update {
  exec { '/usr/bin/apt-get -y update':
    user => 'root'
  }
}

class { 'apt_get_update': stage => preinstall }