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
  ensure   => present,
  value    => 'hello ini world ...',
  metadata => {
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
# kdbkey { 'user/test/puppet/usertest/x1':
#   value => 'asdf',
#   user  => 'bernhard',
#   #provider => 'kdb'
# }


#
# validation
#
$ns_validation = 'user/test/puppet-val'

# we require some validation plugins activated
# on the mountpoint corresponding to our settings
kdbmount { $ns_validation:
  file    => 'puppet-val.ini',
  plugins => ['ini', 'type', 'enum', 'validation', 'range'],
}

# ensure our setting is of type 'short'
# (see '$> kdb info type' for other types)
kdbkey { 'spec/x1':
  prefix    => $ns_validation,
  value     => 11,
  check     => {
    'range' => '0-10'
  },
  provider => 'ruby'
}

kdbkey { 'spec/x2':
  prefix => $ns_validation,
  value  => '5',
  check  => {'type' => 'short' }
}

# the type plugin is also aware of doing range checks
kdbkey { 'spec/x3':
  prefix => $ns_validation,
  value  => 10,
  check  => {
    'type'     => 'short',
    'type/min' => 0,  # lower bound
    'type/max' => 10  # upper bound
  }
}

# enums with array of values
kdbkey { 'spec/enumx':
  prefix => $ns_validation,
  check  => {'enum' => ['low', 'middle', 'high']},
  value  => 'low',
}

# or specify allowed values with on string
# (Note: allowed values have to be enclosed in single quotes and
# seperated by ", ")
kdbkey { 'spec/enum_x2':
  prefix => $ns_validation,
  check  => { 'enum' => "'one', 'two', three'" },
  value  => 'one'
}

# ensure only valid absolute path names are used
kdbkey { 'spec/path_key':
  prefix => $ns_validation,
  check  => 'path',
  value  => '/this/is/an/abolute/path'
}

# do regular expression checks on key settings
kdbkey { 'spec/regex_key':
  prefix         => $ns_validation,
  check          => {
    'validation' => '^hello (world|master)$',
    #'validation/ignorecase' => 0,
  },
  value  => 'hello world',
}

kdbkey { 'spec/short2':
  comments => "

 this is a simple short value

 no bound checks are performed",
  prefix   => $ns_validation,
  check    => { type => short },
  value    => 5
}



#
# autorequire
#
$mount_ar = 'user/test/puppet-ar'

kdbkey { 's1/x1':
  ensure => present,
  prefix => $mount_ar,
}

kdbkey { 's3/x2':
  prefix => $mount_ar,
  value  => "hello"
}

kdbkey { 
  "$mount_ar/s2/x3": value => 'xx3', metadata => {'internal/ini/key/number' => '1'};
  "$mount_ar/s2/x4": value => 'xx4', metadata => {'internal/ini/key/number' => '2'};
  "$mount_ar/s2/x5": value => 'xx5', metadata => {'internal/ini/key/number' => '3'};
  "$mount_ar/s2/x6": value => 'xx6', metadata => {'internal/ini/key/number' => '4'};
  "$mount_ar/s2/x7": value => 'xx7', metadata => {'internal/ini/key/number' => '5'};
}

kdbmount { $mount_ar:
  file    => 'puppet-arxx.ini',
  plugins => ['ini', 'type']
}
