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

  newparam(:name) do
    desc <<-EOT
      The fully qualified name of the key

      TODO: describe if it is safe or not to use cascading keys?
      EOT

    validate do |name|
      unless name =~ /^(spec|proc|dir|user|system)?\/.+/
        raise ArgumentError, "%s is not a valid libelektra key name" % name
      end
    end

    isnamevar
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
