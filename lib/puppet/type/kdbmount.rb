# encoding: UTF-8
##
# @file
#
# @brief Custom puppet type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#
#require 'puppet/parameter/boolean'

Puppet::Type.newtype(:kdbmount) do
  @doc = <<-EOT
    Manage libelekra global key-space.

    This resource type allows to define and manipulate libelektra's global key
    database. Libelektra allows to 'mount' external configuration files into
    its key database. A specific libelektra backend plugin is for reading and
    writing the configuration file. 
    ...
    EOT

  ensurable

  newparam(:name) do
    desc <<-EOT
      The fully qualified mount path within the libelektra key database.

      TODO: describe if it is safe or not to use cascading keys?
      EOT

    validate do |name|
      # TODO: which namespaces are safe to use?
      #unless name =~ /^(spec|proc|dir|user|system)?\/.+/
      unless name =~ /^(spec|dir|user|system)?\/.+/
        raise ArgumentError, "%s is not a valid libelektra key name" % name
      end
    end

    isnamevar
  end

  newproperty(:file) do
    desc <<-EOT
    The configuration file to mount into the libelektra key database.
    EOT
    # TODO: do we have any restrictions on this?
  end

  # for now we do not support changing plugins and there settins
  # so we use a param for this NOW
  #newproperty(:plugins, :array_matching => :all) do
  newparam(:plugins) do
    desc <<-EOT
    A list of libelektra plugins to use for mounting.
    TODO: finish this
    EOT

    munge do |plugins|
      puts "plugins munge: #{value}"
      config_args = []

      if plugins.is_a? String
        config_args << plugins

      elsif plugins.is_a? Array
        plugins.each do |elem|
          if elem.is_a? String
            config_args << elem
          elsif elem.is_a? Hash
            # we've got a config hash for the previous plugin
            config_line = ''
            elem.each do |plugin_config, value|
              config_line << ',' unless config_line.empty?
              config_line << "#{plugin_config}=#{value}"
              #config_line << plugin_config
              #config_line << "=#{value}" unless value.empty?
            end
            config_args << config_line
          end
        end
      end

      return config_args
    end
  end

  def exists?
    #puts "type kdbmount exists? #{self[:name]}"
    @provider.get(:ensure) != :absent
  end


  def self.plugins_to_config_args(plugins)
  end
end
