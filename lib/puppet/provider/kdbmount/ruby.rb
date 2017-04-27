# encoding: UTF-8
##
# @file
#
# @brief Ruby provider for type kdbmount for managing libelektra key database
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

module Puppet
  Type.type(:kdbmount).provide :ruby do
    desc "kdbmount through libelektra Ruby API"

    @@have_kdb = true

    begin
      require 'kdbtools'
    rescue LoadError
      @@have_kdb = false
    end

    defaultfor :kernel => :Linux
    confine :true => @@have_kdb

    # generate getter and setter
    mk_resource_methods


    # find all existing instances
    #
    def self.instances
      mounts = []
      get_active_mountpoints.each do |hash|
        if hash
          mounts << new(hash)
        end
      end
      return mounts
    end


    def self.prefetch(defined_mountpoints)
      #defined_mountpoints.each do |name, res|
      #  Puppet.debug "defined mp: name: #{name}, file: #{res[:file]}"
      #end
      instances.each do |prov_inst|
        if resource = defined_mountpoints[prov_inst.name]
          resource.provider = prov_inst
        end
      end
    end


    def create
      Puppet.debug "kdbmount:ruby: create #{@resource}"
      perform_kdb_action Kdbtools::MOUNTPOINTS_PATH,
                         &method(:set_mount_backend_config)
    end


    def destroy
      perform_kdb_action Kdbtools::MOUNTPOINTS_PATH,
                         &method(:set_unmount_backend_config)
    end


    def recreate
      perform_kdb_action Kdbtools::MOUNTPOINTS_PATH,
                         &method(:reset_backend_config)
    end


    #def exists?
    # this is defined in Type as we use prefetch
    #end


    #def file
    #  puts "getting file"
    #end

    def file=(value)
      begin
        #Kdb.open do |kdb|
          backend_root = Kdb::Key.new Kdbtools::MOUNTPOINTS_PATH
          backend_root.add_basename @resource[:name]

        #  mountconf = Kdb::KeySet.new
        #  kdb.get mountconf, backend_root
        perform_kdb_action backend_root do |mountconf|

          if path_key.nil?
            raise Puppet::Error, "path key not found in backend config"
          end

          path_key.value = @resource[:file]

        #  kdb.set mountconf, backend_root
        end
      rescue
        Puppet.debug "could not set file within backend, fallback to recreate mountpoint"
        # fallback, recreate mountpoint
        recreate
      end
    end


    def plugins=(value)
      # this is pretty the same as building the backend and replace the current
      # backend config with the new one
      recreate
    end

    def resolver=(value)
      recreate
    end

    #def flush
    #  puts "do flush of #{@resource[:name]}"
    #  puts @property_hash
    #  puts "plugins: #{@resource[:plugins]}"
    #end


    def resolve_plugins(plugins)
      result = {}
      plugins.each do |plugin|
        backend = Kdbtools::MountBackendBuilder.new
        backend.add_plugin Kdbtools::PluginSpec.new(plugin)
        backend.resolve_needs @resource[:add_recommended_plugins]
        backend.to_add.each do |ps|
          result[plugin] ||= []
          result[plugin] << ps.name
          result[plugin] << ps.refname if ps.name != ps.refname
        end
      end
      return result
    end


    # convert the Puppet given :plugins value to a more suitable
    # hash:
    #   pluginname => plugin config settings
    #
    # Puppet will give us an array of values, combining plugin names and
    # config settings. e.g.
    # ["ini", {"delimiter" => " ", "setting2" => "aa"}, "type"]
    #
    # e.g:
    #   ini => {
    #     delimiter => " "
    #     array     => ""
    #   },
    #   type => { }
    #
    def convert_plugin_settings(plugins)
      config = {}
      cur_plugin = nil
      if plugins.is_a? Array and plugins.size == 1 and plugins[0].is_a? Hash
        # if we have a single array element and this is a Hash, user has passed
        # a Hash object to plugins property
        config = plugins[0]
      elsif plugins.is_a? Array
        plugins.each do |e|
          if e.is_a? String
            cur_plugin = e
            config[e] = {}
          elsif e.is_a? Hash
            config[cur_plugin] = e
          else
            raise Puppet::Error, "invalid plugins configuration given"
          end
        end
      end
      return config
    end


    private

    # get all active mountpoint
    #
    def self.get_active_mountpoints
      mp = []
      Kdb.open do |kdb|
        mountconf = Kdb::KeySet.new
        kdb.get mountconf, Kdbtools::MOUNTPOINTS_PATH

        backends = Kdbtools::Backends.get_backend_info mountconf

        backends.each do |mount|
          backend_key = Kdb::Key.new Kdbtools::MOUNTPOINTS_PATH
          backend_key.add_basename mount.mountpoint
          backend_ks = mountconf.cut backend_key

          hash = {}
          hash[:provider] = self.name
          hash[:name] = mount.mountpoint
          hash[:file] = mount.path
          hash[:ensure] = :present
          hash[:plugins] = get_mountoint_plugin_config backend_ks
          mp << hash
        end
      end
      Puppet.debug mp
      return mp
    end


    # get configured plugins with their config settings from a
    # given backend
    #
    def self.get_mountoint_plugin_config(backend)
      plugins = {}
      backend.each do |key|
        # we only search for the plugin keys
        if /\/(error|get|set)plugins\// =~ key.fullname
          # parse the plugin key name
          if /^#([0-9]+)#(\w+)(#(\w+)#)?$/ =~ key.basename
            plugin_name = $2
            #ref_number = $1  # unused
            ref_name = $4
            # skip resolver plugins
            next if ref_name == "resolver"
            next if plugin_name == "resolver"
            next if plugin_name == "sync" # TODO is it save to ignore sync

            #puts "matching plugin: #{$2}, num: #{$1}, refname: #{$4}"

            plugins[plugin_name] = {} unless plugins.include? plugin_name

            # check for config keys
            config_ks = backend.cut Kdb::Key.new key.name + "/config"
            config_ks.each do |config_key|
              # ignore the first dir key
              next if config_key == Kdb::Key.new(key.name + "/config")
              plugins[plugin_name][config_key.basename] = config_key.value
            end
          end
        end
      end
      # convert the Hash to an array Puppet gives us
      plugins = plugins.to_a.flatten.reject {|e| e.empty? }
      #puts "#{plugins}"
      plugins
    end


    # helper function to modify Elektra key database
    # helps to avoid multiple Kdb.open/close sequences
    #
    def perform_kdb_action path, &block
      Kdb.open do |kdb|
        mountconf = Kdb::KeySet.new
        kdb.get mountconf, path

        yield mountconf

        # write new mount config
        kdb.set mountconf, path
      end
    end


    # create a new mount point and add it to the existing
    # mount config (fetched from system/elektra/mountpoints
    # use with perform_kdb_action
    #
    def set_mount_backend_config(mountconf)

      backend = Kdbtools::MountBackendBuilder.new

      # mountpoint
      mpk = Kdb::Key.new @resource[:name]
      unless mpk.is_valid?
        raise Puppet::Error, "invalid mountpoint: #{@resource[:name]}"
      end

      # add new mount point, checks for mountpoint validity and
      # already existing mountpoint
      backend.set_mountpoint mpk, mountconf

      # add the resolver plugin
      backend.add_plugin Kdbtools::PluginSpec.new @resource[:resolver]

      backend.use_config_file @resource[:file]

      backend.need_plugin "storage"

      plugins = convert_plugin_settings(@resource[:plugins])
      plugins_to_mount = {}
      # for each plugin get all dependent (and if req. recommended) plugins
      resolved_plugins = resolve_plugins plugins.keys

      plugins.each do |name, config|
        # if user has specified a plugin configuration, we have to use this
        # plugin for mounting
        unless config.empty?
          plugins_to_mount[name] = config
        end

        # check if this plugin would be added by any other plugin through
        # dependency or recommends lists.
        # If so do not explicetly for mounting, since this might lead to
        # ordering or placement errors
        use_plugin = true
        resolved_plugins.each do |other, depends|
          next if other == name
          if depends.include? name
            use_plugin = false
          end
        end

        if use_plugin
          plugins_to_mount[name] = config
        end
      end

      all_used_plugins = resolved_plugins.values.flatten.uniq.sort
      if plugins.keys.sort != all_used_plugins
        Puppet.notice "#{@resource}: using additional plugins: #{(all_used_plugins - plugins.keys.sort)}"
      end

      #puts "should plugins: #{plugins}"
      #puts "actually used: #{plugins_to_mount}"

      # add user requested plugins
      plugins_to_mount.each do |p_name, p_config|
        ps = Kdbtools::PluginSpec.new p_name
        p_config.each do |k, v|
          ps.append_config Kdb::KeySet.new Kdb::Key.new("user/#{k}", value: v)
        end
        backend.add_plugin ps
      end

      # resolv all required plugins (without recommended (false))
      backend.resolve_needs @resource[:add_recommended_plugins]

      begin
        # add new backend to mount config
        backend.serialize mountconf
      rescue
        raise Puppet::Error, "unable to create mountpoint; #{$!}"
      end
    end


    # remove existing mount point from existing mount config
    # use with perform_kdb_action
    #
    def set_unmount_backend_config(mountconf)
        Kdbtools::Backends.umount @resource[:name], mountconf
    end


    # recreate mount config
    # use with perform_kdb_action
    #
    def reset_backend_config(mountconf)
      set_unmount_backend_config mountconf
      set_mount_backend_config mountconf
    end


  end
end
