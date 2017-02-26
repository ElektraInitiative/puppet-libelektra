# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# https://docs.puppet.com/guides/tests_smoke.html
#

#include ::libelektra

$ns = 'user/test/puppet'

kdbkey { "${ns}/x1":
  ensure => present,
  value  => 'hello world x1 ...'
}

kdbkey { "${ns}/x2":
  ensure => absent
}

kdbkey { "${ns}/x3":
  ensure => present
}

kdbkey { "${ns}/x4":
  ensure          => present,
  value           => 'x4 value ...',
  purge_meta_keys => true,
  metadata        => {
    'meta1' => 'm1 value',
    'meta2' => 'm2 value',
    #'meta3' => 'm3 value'
  },
  comments        => 'hello world'
}

kdbkey { "${ns}-test/section1/setting1":
  ensure          => present,
  value           => 'hello ini world ...',
  metadata        => {
    'comments'    => '#1',
    'comments/#0' => '# this is the first comment line',
    'comments/#1' => '# this is the second comment line'
  }
}

kdbkey { "${ns}-test/section1/setting2":
  ensure   => present,
  value    => 'some value ...',
  comments => '
this setting will do the most important stuff
with a multi line comment
here comes the setting
m line1
m line2'
}


kdbkey { "${ns}-test/section2/setting1":
  value    => 'asdf',
  comments => ''
  #  before => Kdbkey["${ns}-test/section2"]
}


#
# prefix tests
#

# results in "${ns-test}/prefixtest/s1"
kdbkey { '/prefixtest/s1':
  prefix => "${ns}-test",
  value  => 'hello prefix'
}

# results in "${ns-test}/prefixtest/s12"
# will lead to duplicate resource error if it matches the above one (eaven
# with a different resource title)
kdbkey { 'something else':
  name   => '/prefixtest/s12',
  prefix => "${ns}-test",
  value  => 'hello prefix'
}


#
# set keys in the context of a given user
#
kdbkey { 'user/test/puppet/usertest/x1':
  value => 'asdf',
  user  => 'bernhard',
  #provider => 'kdb'
}
