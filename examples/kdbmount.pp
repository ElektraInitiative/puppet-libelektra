


kdbmount { 'system/sw/ssh/sshd':
  ensure   => present,
  file     => '/etc/ssh/sshd_config',
  plugins  => [
    'ini' => {
      'array'     => '',
      'delimiter' => ' '
    }
  ]
  #plugins => ['sync', 'ini']
}

kdbmount { 'system/network/hosts':
  ensure  => present,
  file    => '/etc/hosts',
  plugins => 'hosts'
}
