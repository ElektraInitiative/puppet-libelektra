# Puppet module for libelektra

#### Table of Contents

1. [Description](#description)
    * [Elektra](#elektra)
1. [Setup - The basics of getting started with libelektra](#setup)
    * [Elektra installation](#elektra-installation)
    * [Setup requirements](#setup-requirements)
    * [Beginning with libelektra](#beginning-with-libelektra)
1. [Usage - Basica and Examples](#usage)
1. [Reference - An under-the-hood peek at what the module is doing](#reference)
    * [Kdbkey - manage Elektra keys](#kdbkey)
    * [Kdbmount - manage Elektra mountpoints](#kdbmount)
1. [Limitations](#limitations)
1. [Development - Guide for contributing to the module](#development)
1. [Release Notes](#release-notes)

## Description

Puppet module for *libelektra* (https://www.libelektra.org). This allows
key-value based configuration manipulation.

### Elektra

Elektra is a general purpose key value based configuration framework. It
manages its keys in a global, modular and hierarchically organized key space:

 * **global**: all processes on the same machine access the same key space
 * **hierarchical**: the key space is structured as a tree, similar to the UNIX
   file system. Each key has a unique name, similar to the absolute path of a
   file.
 * **modular**: the key space can be split up in several parts, whereas each
   part corresponds to a different configuration file. This split-up is called
   **mounting**. Similar to a UNIX file system (the whole file system can be
   split in different disks, locations...), the Elektra key space can be built
   up by a set of different configuration files. A set of Elektra plugins define
   how a configuration file is integrated into the Elektra key space (defining
   which storage format is used, conversion parameter...).

This *mounting* process makes Elektra very suitable for Puppet. Mounting allows
us to integrate different configuration files, of different formats, into the
Elektra key space. Once in the key space, configuration settings can be
manipulated on a key value basis. For example, to change the 'workgroup' in
Samba's configuration file everything needed is:
```puppet
kdbmount { 'system/sw/samba':
  file    => '/etc/samba/smb.conf',
  plugins => ['ini']
}

kdbkey { 'system/sw/samba/global/workgroup':
  value => 'MY_WORKGROUP'
}
```

Elektra also provides CLI tools to operate on the Elektra key space:
```sh
$> kdb get system/sw/samba/global/workgroup
MY_WORKGROUP
$> kdb set system/sw/samba/global/workgroup OTHER
Set string to OTHER
```
Another important feature of Elektra is called *configuration specification*.
This allows us to define value (and even structure) restrictions. This means, we
can instruct Elektra to perform validation checks before writing a configuration
file. For example, if an application only accepts numeric values in the range of
1-10 for a certain setting, we can add this check with:
```puppet
kdbmount { 'system/sw/myapp':
  file    => '/etc/myapp/config.ini',
  plugins => ['ini', 'type', 'range']	# add checking plugins
}

kdbkey { 'system/sw/myapp/instances':
  value => $instances,
  check => {
    'type'  => 'short',
    'range' => '1-10'
  }
}
```
This *configuration specification* stored within Elektra, thus it is now active
for other Elektra aware tools:
```
$> kdb set system/sw/myapp/instances 11
The command kdb set failed while accessing the key database with the info:
...
Description: value not within specified range.
Reason: value 11 not within range 1-10
...
```

For further details on Elektra see https://www.libelektra.org/

## Setup

The 'libelektra' Puppet module currently requires a recent Elektra version
(0.8.19) to work correctly.

Elektra has to be installed on each managed node. In theory, Elektra is not
required on the master node, if the master node is unmanaged.

### Elektra installation

For Elektra installation instructions see
[Elektra installation](https://www.libelektra.org/docgettingstarted/installation).


The 'libelektra' Puppet module integrates with Elektra by the Elektra Ruby bindings
or the Elektra CLI tool `kdb`. Although, `kdb` is the minimum requirement for
this module to work, it is **highly** recommended to install Elektra's Ruby
bindings.

### Setup Requirements

We currently only support Linux operating systems. (Tested on Ubuntu Xenial and
Debian Jessie)

### Beginning with libelektra

After a successful Elektra installation, install the 'libelektra' Puppet module.
Currently this can only be done by cloning the Github repo.

Once the module is released, it will be available in Puppet forge.

## Usage

The 'libelektra' Puppet module provides two resource types for managing
configuration files with Elektra:

 * **kdbmount**: mount configuration file into the Elektra key space
 * **kdbkey**: manipulate configuration settings through Elektra

To start configuring your systems with 'libelektra', you first have to integrate
(**mount**) your configuration files into the Elektra key space:
```puppet
kdbmount { 'system/sw/samba':       # Elektra mount path
  file    => '/etc/samba/smb.conf', # path to configuration file
  plugins => ['ini']                # list of Elektra plugins used for mounting
}
```
Now all configuration settings defined in `/etc/samba/smb.conf` are available
under the Elektra path `system/sw/samba`. So `system/sw/samba/global/workgroup`
refers to the setting `workgroup` in section `global` in config file
`/etc/samba/smb.conf`.

Now we can manipulate smb.conf settings:
```puppet
# add a new logging parameter
kdbkey { 'system/sw/samba/global/logging':
  value => 'syslog@1 file'
}

# remove the 'debuglevel' setting
kdbkey { 'system/sw/samba/global/debuglevel':
  ensure => absent
}
```

**Autorequires**: A order relation ship ('requires', 'before'...) between the
`kdbmount` and `kdbkey` definitions is not required. This is added implicitly.

We often manipulate settings under a certain Elektra path. To avoid using the
the full Elektra path over and over again, we can use the `prefix` parameter`
together with resource defaults here:
```puppet
class samba::config {
  $mountpoint = 'system/sw/samba'

  kdbmount { $mountpoint:
    file    => '/etc/samba/smb.conf',
    plugins => ['ini', 'enum']        # use the enum check plugin
  }

  Kdbkey {
    prefix => $mountpoint
  }

  # the Elektra path is concatenated by `prefix` and `name` parameters
  kdbkey { 'global/workgroup':
    value => 'MY_WORKGROUP'
  }

  # it can be even be more readable (Note: ';' at the end)
  kdbkey {
    'global/logging':   value => 'syslog@1 file';
    'global/log level': value => '3 auth:10';
  }

  # sections are created automatically
  kdbkey {
    'my_share/path':
      value   => '/var/data/my_share',
      # goes in smb.conf as comment line
      comment => 'This is my share definition';

    'my_share/comment':
      value => 'This is my share';

    'my_share/guest ok':
      value => 'yes',
      # only allow 'yes' or 'no'
      check => { 'enum' => ['yes', 'no'] };
  }
```

## Reference

Obtained by `puppet doc`

### kdbkey

Manage libelekra keys.

This resource type allows to define and manipulate keys of libelektra's
key database.

#### Parameters

* `name`: The fully qualified name of the key.
* `ensure`: The basic property that the resource should be in.
* `value`: Desired value of the key.
* `prefix`: Prefix for the key name (optional).
* `check`: Add value validation.
* `comments`: Comments for this key.
* `user`: Define or modify key in the context of given user.
* `metadata`: Metadata for this key supplied as Hash of key-value pairs.
* `purge_meta_keys`: Manage complete set of metadata keys.
* `provider`: The specific backend to use for this `kdbkey` resource.

##### Parameter Details

* `check`: Add value validation.

  This property allows to define certain restrictions to be applied on the
  key value, which are automatically checked on each key database write. These
  validation checks are performed by Elektra itself, so modifications done
  by other applications will be also restricted to the defined value
  specifications.

  The value for this property can be either a single String or a Hash
  of settings. The following plugins were tested with puppet-elektra:

  * `path`: check for an absolute path name

    The 'path' plugin does not require any additional settings
    so it is enough to just pass 'path' as 'check' value.
    ```puppet
    kdbkey { 'system/sw/myapp/setting1':
      check => 'path',
      value => '/some/absolute/path/will/pass'
    }
    ```
    Note: this does not check if the path really exists (instead it just
    issues a warning). The check will fail, if the given value is not an
    absolute path.

  * `network`: check for a valid IP address

    The network plugin checks if the supplied value is valid IP address.
    ```puppet
    kdbkey { 'system/sw/myapp/myip':
      check => 'ipaddr',
      value => ${given_myip}
    }
    ```
    to check for valid IPv4 addresses use
    ```puppet
    kdbkey { 'system/sw/myapp/myip':
      check => { 'ipaddr' => 'ipv4' },   # works with 'ipv6' too
      value => $given_myip
    }
    ```

  * `type`: type checks

    The `type` plugin checks if the supplied key value conforms to a defined
    data type (e.g. numeric value). Additionally, it is able to check if
    the supplied key value is within an allowed range.
    ```puppet
    kdbkey { 'system/sw/myapp/port':
      check => { 'type' => 'unsigned_long' },
      value => $given_port
    }

    kdbkey { 'system/sw/myapp/num_instances':
      check => {
        'type' => 'short',
        'type/min' => 1,
        'type/max' => 20
      },
      value => $given_num_instance
    }
    ```

  * `range`: checks if value is within one ore more ranges

    ```puppet
    kdbkey { 'system/sw/myapp/value':
      check => { 'range' => '1-10,12-20' },  # <1, 11 and >20 is not allowed
      value => $value
    }
    ```

  * `enum`: define a list of valid values

    The enum plugin check it the supplied value is within a predefined set
    of values. Two different formats are possible:
    ```puppet
    kdbkey { 'system/sw/myapp/scheduler':
      # as string, values seperated with ', ' and encloseed by '
      check => { 'enum' => "'ondemand', 'performance', 'energy saving'" },
      value => $given_scheduler
    }

    kdbkey { 'system/sw/myapp/notification':
      # as array of strings
      check => { 'enum' => ['off', 'email', 'slack', 'irc'] },
      value => $given_notification
    }
    ```

  * `validation`: perform regular expression checks

    The validation plugin checks if the supplied value matches a predefined
    regular expression:
    ```puppet
    kdbkey { 'system/sw/myapp/email':
      check => {
        'validation' => '^[a-z0-9._]+@mycompany.com$'
        'validation/message' => 'we require an internal email address here',
        'validation/ignorecase' => '',  # existence of flag is enough
      }
      ...
    }
    ```

  For further plugins see the Elektra
  [plugin documentation](https://www.libelektra.org/plugins/readme).

  Note: for each 'check/xxx' metadata, required by the Elektra plugins, just
  remove the 'check/' part and add it to the 'check' property here.
  (e.g. validation plugin: 'check/validation' => 'validation' ...)

* `comments`: comments for this key

  Comments form a critical part of documentation. May configuration file
  formats support adding comment lines. Libelektra plugins parse comments
  and add them as metadata keys to the corresponding keys. This attribute
  allows to manage those comment lines.

  Multi-line comments (those including a newline character) are implicitly
  converted to a multi-line comment.

* `ensure`: The basic property that the resource should be in.

  Valid values are `present`, `absent`.

* `metadata`: Metadata for this key supplied as Hash of key-value pairs.

  The concrete  behaviour is defined by the parameter `purge_meta_keys`.
  The default case (`purge_meta_keys` => false) is to manage the specified
  metadata keys only. Already present but not specified metadata keys will not
  be removed. If `purge_meta_keys` is set to true, already present but not
  specified metadata keys will be removed.

  Examples:
  ```puppet
  kdbkey { 'system/sw/app/s1':
    metadata => {
      'owner'      => 'me',
      'other meta' => 'you'
      }
  }
  ```

* `name`: The fully qualified name of the key

  (**Namevar:** If omitted, this parameter's value defaults to the resource's title.)

  Elektra manages its keys within several namespaces ('system', 'user',
  'dir'... see
  [Elektra-namespaces](https://www.libelektra.org/manpages/elektra-namespaces)
  for details.)

  Cascading key names (keys starting with a '/') are probably not optimal
  here, as they are implicitly converted to a key name with the 'dir',
  'user' or 'system' namespace.

* `prefix`: Prefix for the key name (optional)

  If given, this value will prefix the given libelektra key name.
  e.g.:
  ```puppet
    kdbkey { 'puppet/x1':
      prefix => 'system/test',
      value  => 'hello'
    }
  ```
  This will manage the key 'system/test/puppet/x1'.

  Prefix and name are joined with a '/', if prefix does not end with '/'
  or name does not start with '/'.

  Both, name and prefix parameter are used to uniquely identify a
  libelektra key.

* `provider`: The specific backend to use for this `kdbkey` resource.

  You will seldom need to specify this --- Puppet will usually
  discover the appropriate provider for your platform.

  Default: `ruby` if Ruby bindings are installed

  Available providers are:

  * kdb: manage keys through `kdb` command

    * Required binaries: `kdb`.
    * Supported features: `user`.

  * ruby: manage keys through libelektra Ruby API

    * Supported features: `user`.

* `purge_meta_keys`: manage complete set of metadata keys

  If set to true, kdbkey will remove all unspecifed metadata keys, ensuring
  only the specified set of metadata keys will exist. Otherwise,
  unspecified metadata keys will not be touched.

  Valid values are `true`, `false`, `yes`, `no`.

* `user`: define/modify key in the context of given user.

  This is only relevant, if key name referes to a user context, thus is
  either cascading (starting with a '/') or is within the 'user'
  namespace (starting with 'user/').

* `value`: Desired value of the key.

  This can be any type, however elektra currently
  just manages to store String values only. Therefore all types are
  implicitly converted to Strings.

  If value is an array, the key is managed as an Elektra array. Therefore
  a subkey named `<name>/#<index>` will be created for each array element.



### kdbmount

Manage libelekra global key-space.

This resource type allows to define and manipulate libelektra's global key
database. Libelektra allows to 'mount' external configuration files into
its key database. A specific libelektra backend plugin is for reading and
writing the configuration file.

#### Parameters

* `name`: The fully qualified mount path within the libelektra key database.
* `ensure`: The basic property that the resource should be in.
* `file`: The configuration file to mount into the Elektra key database.
* `plugins`: A list of libelektra plugins with optional configuration settings
* `provider`: The specific backend to use for this `kdbmount` resource.
* `resolver`: The resolver plugin to use for mounting.
* `add_recommended_plugins`: If set to true, Elektra will add recommended

##### Parameter Details

* `add_recommended_plugins`: If set to true, Elektra will add recommended
  plugins to the mounted backend configuration.
  Recommended plugins are: sync
  Default: false

  Valid values are `true`, `false`, `yes`, `no`.

* `ensure`: The basic property that the resource should be in.

  Valid values are `present`, `absent`.

* `file`: (**mandatory**) The configuration file to mount into the Elektra
  key database.

* `name`: The fully qualified mount path within the libelektra key database.

* `plugins`: (**mandatory**) A list of libelektra plugins with optional
  configuration settings
  use for mounting.

  The following value formats are acceped:
  - a string value describing a single plugin name
  - an array of string values each defining a single plugin
  - a hash of plugin names with corresponding configuration settings
    e.g.
    ```puppet
      [ 'ini' => {
            'delimiter' => " "
            'array'     => ''
            },
        'type'
      ]
    ```

* `provider`: The specific backend to use for this `kdbmount` resource.
  You will seldom need to specify this --- Puppet will usually discover the
  appropriate provider for your platform.

  Available providers are:

  * `kdb`: kdbmount through kdb command

    * Required binaries: `kdb`.

  * `ruby`: kdbmount through libelektra Ruby API

    * Default for `kernel` == `Linux`.

* `resolver`: The resolver plugin to use for mounting.

  Default: 'resolver'





## Limitations

The 'libelektra' Puppet module was only tested with Puppet 3.x (3.8). Since
Puppet 4.x uses its own Ruby runtime, the system installed Elektra Ruby bindings
can't be used by 'libelektra'. Thus the fallback provider `kdb` for both
resource types (kdbkey and kdbmount) are usable only.

## Development

This module is hosted under
https://github.com/ElektraInitiative/puppet-libelektra

Contributions welcome ;)

## Release Notes

Currently the 'libelektra' Puppet module is under heavy development. No releases
till now.
