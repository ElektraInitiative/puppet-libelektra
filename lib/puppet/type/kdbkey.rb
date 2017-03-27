# encoding: UTF-8
##
# @file
#
# @brief Custom puppet type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:kdbkey) do
  @doc = <<-EOT
    Manage libelekra keys.

    This resource type allows to define and manipulate keys of libelektra's
    key database.
    EOT

  feature :user, "ability to define/modify keys in the context of a specific user"


  ensurable

  # prefix parameter
  #
  # Note: this has to be defined BEFORE the name parameter, since we reference
  # this prefix parameter within the names 'muge' and 'validate' methods
  newparam(:prefix) do
    desc <<-EOT
    Prefix for the key name (optional)

    If given, this value will prefix the given libelektra key name.
    e.g.:

      kdbkey { 'puppet/x1':
        prefix => 'system/test',
        value  => 'hello'
      }

    This will manage the key 'system/test/puppet/x1'.

    Prefix and name are joined with a '/', if prefix does not end with '/'
    or name does not start with '/'.

    Both, name and prefix parameter are used to uniquely identify a
    libelektra key.
    EOT

    isnamevar

    defaultto ""

    validate do |name|
      unless name.nil? or name.empty?
        unless name =~ /^(\/|spec|proc|dir|user|system)/
          raise ArgumentError, "'%s' is not a valid basename" % name
        end
      end
    end
  end


  # name parameter
  newparam(:name) do
    desc <<-EOT
      The fully qualified name of the key

      TODO: describe if it is safe or not to use cascading keys?
      EOT

    # add the prefix, if given
    munge do |value|
      if resource[:prefix].nil?
        value
      else
        fullname = resource[:prefix]
        fullname += "/" unless fullname[-1] == "/" or value[0] == "/"
        fullname += value
        fullname.gsub! "//", "/"
        @resource.title = fullname
      end
    end

    # if no prefix is given, we have to validate the key name
    validate do |name|
      if resource[:prefix].nil? or resource[:prefix].empty?
        unless name =~ /^(spec|proc|dir|user|system)?\/.+/
          raise ArgumentError, "'%s' is not a valid libelektra key name" % name
        end
      end
    end

    isnamevar
  end

  # this is required, since we've defined to parameter as 'namevar'
  # it's used to assign the name from the resource title, whereas the default
  # implementation will raise an error if two name vars are given
  # (see type.rb for details)
  def self.title_patterns
    [ [ /(.*)/m, [ [:name] ] ] ]
  end


  newproperty(:value, :array_matching => :all) do
    desc <<-EOT
      Desired value of the key. This can be any type, however elektra currently
      just manages to store String values only. Therefore all types are
      implicitly converted to Strings.

      If value is an array, the key is managed as an Elektra array. Therefore
      a subkey named `*name*/#<index>` will be created for each array element.
      EOT

    def change_to_s(current_value, new_value)
      def single_elem_as_string(v)
        return "" if v.nil?
        if v.is_a? Array and v.size == 1
          return v[0].to_s
        else
          return v.to_s
        end
      end

      "value changed '#{single_elem_as_string current_value}' to '#{single_elem_as_string new_value}'"
    end
  end

  newproperty(:metadata) do
    desc <<-EOT
      Metadata for this key supplied as Hash of key-value pairs. The concret
      behaviour is defined by the parameter `purge_meta_keys`. The default
      case (`purge_meta_keys` => false) is to manage the specified metadata
      keys only. Already present but not specified metadata keys will not be
      removed. If `purge_meta_keys` is set to true, already present but not
      specified metadata keys will be removed.

      Examples:
      kdbkey { 'system/sw/app/s1':
        metadata => {
          'owner'      => 'me',
          'other meta' => 'you'
          }
      }
      EOT

    validate do |metadata|
      if !metadata.is_a? Hash
        raise ArgumentError, "Hash required"
      else
        super metadata
      end
    end
  end

  newparam(:purge_meta_keys,
           :boolean => true,
           :parent => Puppet::Parameter::Boolean) do
    desc <<-EOT
      manage complete set of metadata keys

      If set to true, kdbkey will remove all unspecifed metadata keys, ensuring
      only the specified set of metadata keys will exist. Otherwise,
      unspecified metadata keys will not be touched.
      EOT
  end

  newproperty(:comments) do
    desc <<-EOT
      comments for this key

      Comments form a critical part of documentation. May configuration file
      formats support adding comment lines. Libelektra plugins parse comments
      and add them as metadata keys to the corresponding keys. This attribute
      allows to manage those comment lines.

      TODO finish this docu

      EOT

    def change_to_s(current_value, new_value)
      # limit max string length
      current_value = "#{current_value[0,20]}..." if current_value.size > 24
      new_value = "#{new_value[0,20]}..." if new_value.size > 24
      # replace new lines with $
      current_value.gsub! "\n", '$ '
      new_value.gsub! "\n", '$ '

      if current_value.empty?
        return "comments defined to '#{new_value}'"
      elsif new_value.empty?
        return "comments removed"
      else
        return "comments changed '#{current_value}' to '#{new_value}'"
      end
    end
  end

  newproperty(:check) do
    desc <<-EOT
    Add value validation.

    This property allows to define certain restrictions to be applied on the
    key value, which are automatically checked on each key database write. These
    validation checks are performed by Elektra itself, so modifications done
    by other applications will be also restricted to the defined value
    specifications.

    The value for this property can be either a single String or a Hash
    of settings.
    e.g. path plugin
      the 'path' plugin does not require any additional settings
      so it is enough to just pass 'path' as 'check' value.

      kdbkey { 'system/sw/myapp/setting1':
        check => 'path',
        value => '/some/absolute/path/will/pass'
      }

      Note: this does not check if the path really exists (instead it just
      issues a warning). The check will fail, if the given value is not an
      absolute path.

    e.g. network plugin

      The network plugin checks if the supplied value is valid IP address.

      kdbkey { 'system/sw/myapp/myip':
        check => 'ipaddr',
        value => ${given_myip}
      }

      to check for valid IPv4 addresses use

      kdbkey { 'system/sw/myapp/myip':
        check => { 'ipaddr' => 'ipv4' },   # works with 'ipv6' too
        value => ${given_myip}
      }

    e.g. type plugin

      The type plugin checks if the supplied key value conforms to a defined
      data type (e.g. numeric value). Additionally, it is able to check if
      the supplied key value is within an allowed range.

      kdbkey { 'system/sw/myapp/port':
        check => { 'type' => 'unsigned_long' },
        value => ${given_port}
      }

      kdbkey { 'system/sw/myapp/num_instances':
        check => {
          'type' => 'short',
          'type/min' => 1,
          'type/max' => 20
        },
        value => ${given_num_instance}
      }

    e.g. enum plugin

      The enum plugin check it the supplied value is within a predefined set
      of values. Two different formats are possible:

      kdbkey { 'system/sw/myapp/scheduler':
        check => { 'enum' => "'ondemand', 'performance', 'energy saving'" },
        value => ${given_scheduler}
      }

      kdbkey { 'system/sw/myapp/notification':
        check => { 'enum' => ['off', 'email', 'slack', 'irc'] },
        value => ${given_notification}
      }

    e.g. validation plugin

      The validation plugin checks if the supplied value matches a predefined
      regular expression:

      kdbkey { 'system/sw/myapp/email':
        check => {
          'validation' => '^[a-z0-9\._]+@mycompany.com$'
          'validation/message' => 'we require an internal email address here',
          'validation/ignorecase' => '',  # existence of flag is enough
        }
        ...
      }


    For further check plugins see the Elektra documentation.

    Note: for each 'check/xxx' metadata, required by the Elektra plugins, just
    remove the 'check/' part and add it to the 'check' property here.
    (e.g. validation plugin: 'check/validation' => 'validation' ...)
    EOT

    validate do |value|
      # setting specifications for spec/ keys does not make any sense
      # so we do not allow it
      if @resource[:name].start_with? "spec/"
        raise ArgumentError, "setting specifications on a 'spec' key "\
                             "is not allowed and does not make sense"
      end
      unless value.is_a? Hash or value.is_a? String
        raise ArgumentError, "Hash required"
      else
        super value
      end
    end
  end

  # param user
  #
  # This is currently only supported by Provider 'kdb'.
  # However, it seams the 'feature' stuff is evaluated only for once for all
  # instances, so we can not really say, use provider 'kdb' for those with
  # 'user' set and provider 'ruby' for all other instances. This is not working
  # or at least for me it was not working. So we do it manually.
  newparam(:user) do #, :required_features => ["user"]) do
    desc <<-EOT
    define/modify key in the context of given user.

    This is only relevant, if key name referes to a user context, thus is
    either cascading (starting with a '/') or is within the 'user'
    namespace (starting with 'user/').
    EOT

    # misuse the validate method, to change the provider, if required
    validate do |value|
      if provider.class.name != :kdb
        Puppet.debug "Puppet::Type::Kdbkey: change provider to 'kdb' (required by param 'user')"
        @resource.provider= :kdb
      end
    end

  end

  autorequire(:kdbmount) do
    get_autorequire_path_names true
  end

  autorequire(:kdbkey) do
    get_autorequire_path_names false
  end

  def get_autorequire_path_names(include_self)
    if self[:name].is_a? String

      # split name into path elements, so token separated by '/' not including 
      # escaped '/' occurrences
      # Thus, when we detect a '\\' at the end of a token, we do not want
      # to split this up
      names = self[:name].split '/'
      remember = nil
      names.collect! do |token|
        next unless token.is_a? String
        next if token.empty?
        if token[-1] == '\\'
          remember ||= ""
          remember << "/" unless remember.empty?
          remember << token
          next
        elsif !remember.nil?
          ret = remember << "/" + token
          remember = nil
          ret
        else
          token
        end
      end
      # the previous escaped / token joining returns nils, so remove them
      names.compact!

      # generate an array where each element is joined (by a '/') with its
      # previous elements
      req_resources = [names.shift]
      names.each do |n|
        req_resources << req_resources.last + "/" + n
      end

      # if include_self == false remove the last entry (equals :name)
      req_resources.delete self[:name] unless include_self

      # if we have a cascading key, we could access any possible Elektra
      # namespace, thus we autorequire all of them
      if self[:name][0] == '/'
        ns_res = []
        ["system", "user", "spec", "dir"].each do |ns|
          req_resources.each do |name|
            ns_res << ns + '/' + name
          end
        end
        req_resources = ns_res
      end
      req_resources
    end
  end

end
