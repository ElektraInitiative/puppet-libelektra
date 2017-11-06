
kdbmount { 'system/network/hosts':
  ensure  => present,
  file    => 'myhosts',
  plugins => 'hosts'
}

kdbkey { 'dragon':
  prefix => 'system/network/hosts/ipv4',
  value  => '192.168.1.140',
  check  => 'network'
}

kdbkey { 'dragon/office':
  ensure => present,
  #  value  => '192.168.1.140',
  prefix => 'system/network/hosts/ipv4',
}

kdbkey { 'dragon/dell':
  ensure => present,
  prefix => 'system/network/hosts/ipv4',
}

kdbkey { 'blacksheep':
  prefix   => 'system/network/hosts/ipv4',
  value    => '192.168.1.118',
  check    => 'network',
  comments => 'headless virtualization host
  other

  comment'
}
