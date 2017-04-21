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


Puppet::Type.newtype(:kdbmount) do
  @doc = <<-EOT
    Manage libelekra global key-space.

    This resource type allows to define and manipulate libelektra's global key
    database. Libelektra allows to 'mount' external configuration files into
    its key database. A specific libelektra backend plugin is for reading and
    writing the configuration file.
    ...
    EOT

  RECOMMENDED_PLUGINS = ["sync"]


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
    The configuration file to mount into the Elektra key database.
    EOT
    # TODO: do we have any restrictions on this?
  end


  #newproperty(:resolver) do
  newparam(:resolver) do
    desc <<-EOT
      The resolver plugin to use for mounting.
      Default: 'resolver'
    EOT

    defaultto "resolver"

    validate do |value|
      unless @resource.class.plugin_name_is_valid? value
        raise ArgumentError, "'%s' is not a valid plugin name" % value
      end
    end
  end


  newparam(:add_recommended_plugins,
           :boolean => true,
           :parent => Puppet::Parameter::Boolean) do
    desc <<-EOT
      If set to true, Elektra will add recommended plugins to the mounted
      backend configuration.
      Recommended plugins are: #{RECOMMENDED_PLUGINS.join ', '}
      Default: true
    EOT
    defaultto :true
  end


  # for now we do not support changing plugins and there settings
  # so we use a param for this NOW
  newproperty(:plugins, :array_matching => :all) do
  #newparam(:plugins) do
    desc <<-EOT
    A list of libelektra plugins with optional configuration settings
    use for mounting.

    The following value formats are acceped:
    - a string value describing a single plugin name
    - an array of string values each defining a single plugin
    - a hash of plugin names with corresponding configuration settings
      e.g.
        [ 'ini' => {
              'delimiter' => " "
              'array'     => ''
              },
          'type'
        ]

    EOT

    validate do |value|
      if value.is_a? String
        unless @resource.class.plugin_name_is_valid? value
          raise ArgumentError, "'%s' is not a vlid plugin name" % value
        end
      end
    end
    # this can't be done here, since we get each value at once for
    # munge, thus one munge call for each array entry.
    #munge do |plugins|
    #  # convert plugins array to a hash
    #end

    # TODO implement this to allow better plugins handling
    #def insync?(value)
    #  puts "insync? #{value}"
    #  false
    #end

  end


  def exists?
    #puts "type kdbmount exists? #{self[:name]}"
    @provider.get(:ensure) != :absent
  end

  def self.plugin_name_is_valid?(name)
    /^\w+$/ =~ name
  end

end
