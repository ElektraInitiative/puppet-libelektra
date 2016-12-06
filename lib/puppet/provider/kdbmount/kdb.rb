# encoding: UTF-8
##
# @file
#
# @brief Kdb provider for type kdbmount for managing libelektra key database
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

module Puppet
  Type.type(:kdbmount).provide :kdb do
    desc "kdbmount through kdb command"

    commands :kdb => "kdb"

    mk_resource_methods

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
      #  puts "defined mp: name: #{name}, file: #{res[:file]}"
      #end
      instances.each do |prov_inst|
        if resource = defined_mountpoints[prov_inst.name]
          resource.provider = prov_inst
        end
      end
    end

    def create
      cmd_args = ["mount"]
      cmd_args << @resource[:file]
      cmd_args << @resource[:name]  # mountpoint
      cmd_args += @resource[:plugins] unless @resource[:plugins].nil?
      kdb(cmd_args)
    end

    def destroy
      kdb ["umount", @resource[:name]]
    end

    #def exists?
    # this is defined in Type as we use prefetch
    #end

    #def file
    #  puts "getting file"
    #end

    def file=(value)
    #  puts "setting file to #{value}"
    #  @property_hash[:file] = value
      # changing file is simply done via recreation (for NOW)
      destroy
      create
    end

    #def plugins=(value)
    #  puts "setting plugins #{value}"
    #end

    #def flush
    #  puts "do flush of #{@resource[:name]}"
    #  puts @property_hash
    #  puts "plugins: #{@resource[:plugins]}"
    #end

    private

    def self.get_active_mountpoints
      mp = []
      lines = kdb(["mount"]).split "\n"
      lines.each do |mount_line|
        mp << parse_mount_line(mount_line)
      end
      return mp
    end

    def self.parse_mount_line(mount_line)
      hash = nil

      if /^(.+) on (.+) with name (.+)$/ =~ mount_line
        (file, path, _name) = $~[1,3]
        #puts "got: file: #{file}, path: #{path}, name: #{name}"
        hash = {}

        hash[:provider] = self.name
        # assuming path is the correct value for our 'name' var
        hash[:name] = path
        hash[:file] = file
        hash[:ensure] = :present
      else
        raise Puppet::Error, "'kdb mount' invalid line: #{mount_line}"
      end

      return hash
    end



  end
end
