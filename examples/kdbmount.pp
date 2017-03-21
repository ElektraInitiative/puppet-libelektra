


kdbmount { 'system/sw/ssh/sshd':
  ensure   => present,
  file     => '/etc/ssh/sshd_config',
  plugins  => [
    'ini' => {
      'array'     => '',
      'delimiter' => ' '
    },
  ]
  #plugins => ['sync', 'ini']
}

kdbmount { '/test/cascading':
  ensure  => present,
  file    => 'test.ini',
  plugins => 'ini'
}

kdbmount { '/test/cas2':
  file     => '/tmp/test.ini',
  resolver => 'noresolver'
}


kdbmount { 'system/jenkins':
  file       => '/tmp/jenkins.xml',
  plugins    => [
    'augeas' => {
      #'lens' => '/usr/share/augeas/lenses/dist/xml.aug'
      'lens' => 'Xml.lns'
    }
  ]
}
