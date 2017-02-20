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
    rescue
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
            raise Puppet::Error.new "path key not found in backend config"
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
      plugins = plugins.to_a.flatten.reject {|e| e.empty? }
      #puts "#{plugins}"
      plugins
    end


    # convert the Puppet given :plugins value to a more suitable
    # hash:
    #   pluginname => plugin config settings
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
      if plugins.respond_to? :each
        plugins.each do |e|
          if e.is_a? String
            cur_plugin = e
            config[e] = {}
          elsif e.is_a? Hash
            config[cur_plugin] = e
          else
            Puppet::Error "invalid plugins configuration given"
          end
        end
      end
      return config
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


    # create a new mount point and add it the the existing
    # mount config (fetched from system/elektra/mountpoints
    # use with perform_kdb_action
    #
    def set_mount_backend_config(mountconf)

      backend = Kdbtools::MountBackendBuilder.new

      # mountpoint
      mpk = Kdb::Key.new @resource[:name]
      unless mpk.is_valid?
        raise Puppet::Error "invalid mountpoint: #{@resource[:name]}"
      end

      # add new mount point, checks for mountpoint validity and
      # already existing mountpoint
      backend.set_mountpoint mpk, mountconf

      # add the resolver plugin
      backend.add_plugin Kdbtools::PluginSpec.new @resource[:resolver]

      backend.use_config_file @resource[:file]

      backend.need_plugin "storage"

      @resource.class.const_get(:RECOMMENDED_PLUGINS).each do |p|
        backend.recommend_plugin p
      end

      plugin_config = convert_plugin_settings(@resource[:plugins])
      # add user requested plugins
      plugin_config.each do |p_name, p_config|
        ps = Kdbtools::PluginSpec.new p_name
        p_config.each do |k, v|
          ps.append_config Kdb::KeySet.new Kdb::Key.new("user/#{k}", value: v)
        end
        backend.add_plugin ps
      end

      # resolv all required plugins (without recommended (false))
      backend.resolve_needs @resource[:add_recommended_plugins]

      # add new backend to mount config
      backend.serialize mountconf
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
