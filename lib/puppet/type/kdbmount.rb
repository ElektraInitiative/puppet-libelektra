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
          raise ArgumentError, "'%s' is not a valid plugin name" % value
        end
      end
    end
    # this can't be done here, since we get each value at once for
    # munge, thus one munge call for each array entry.
    #munge do |plugin|
    #end

    # customized insync? method to handle more complex cases.
    # a plugin can have dependencies and can recommend other plugins, therefore
    # during mounting a plugin, Elektra might add additional plugins. So the
    # is and should in two subsequent runs might differ.
    # This method checks,
    # - if we have to add a newly specified plugin (not found in the current
    #    mounted plugin list) 
    # - if we really have to remove a plugin
    # - if plugin config settings have changed
    def insync?(is)
      #puts "insync? is: #{is}, should #{should}"
      return false unless provider.respond_to? :resolve_plugins

      # convert to plugins-config Hash
      my_is = provider.convert_plugin_settings is
      my_should = provider.convert_plugin_settings should


      # fist, check if all :should plugins are in :is plugins array
      # so, is there a plugin missing?
      return false if my_should.keys.any? { |p| not my_is.include? p }

      # pass the :should plugins list to libelektra to get a list plugins that
      # will be used when mounting is done with these
      # (honores :add_recommended_plugins parameter)
      resolved = provider.resolve_plugins my_should.keys
      will_use_plugins = resolved.values.flatten.uniq

      #puts "resolved: #{resolved}"
      #puts "will_use_plugins: #{will_use_plugins}"

      # now, check if plugins should be removed
      # if we have mounted a plugin, which is not in the list of plugins which
      # will be used when mounting with the :should plugins, we have to remove
      # it
      my_is.keys.each do |is_plugin|
        return false unless will_use_plugins.include? is_plugin
      end

      # now do the reverse order, check if all will use are actually used
      # (this is possible if someone switches :add_recommended_plugins
      #  from false to true)
      will_use_plugins.each do |p|
        return false unless my_is.include? p
      end

      # finally, check if some plugin configuration has changed
      my_should.each do |plugin, config|
        return false unless my_is.include? plugin
        return false unless my_is[plugin] == config
      end

      true
    end

    # TODO: add nice formating messages when changing plugins
    #def change_to_s(cur_value, new_value)
    #  return "changed: will_use_plugins: #{@will_use_plugins}"
    #end

  end


  def exists?
    #puts "type kdbmount exists? #{self[:name]}"
    @provider.get(:ensure) != :absent
  end

  def self.plugin_name_is_valid?(name)
    /^\w+$/ =~ name
  end

  validate do
    # make :file and :plugins properties mandatory if one of them are used
    if @parameters.include?(:plugins)
      self.fail("file property missing") unless @parameters.include?(:file)
    end

    if @parameters.include?(:file)
      self.fail("plugins property missing") unless @parameters.include?(:plugins)
    end
  end


end
