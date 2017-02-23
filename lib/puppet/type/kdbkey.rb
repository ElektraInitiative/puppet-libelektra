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
        fullname.gsub "//", "/"
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


  newproperty(:value) do
    desc <<-EOT
      Desired value of the key.
      EOT
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

end
