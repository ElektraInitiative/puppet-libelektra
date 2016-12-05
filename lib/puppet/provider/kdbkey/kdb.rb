# encoding: UTF-8
##
# @file
#
# @brief Kdb provider for type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

module Puppet
  Type.type(:kdbkey).provide :kdb do
    desc "kdb through kdb command"

    commands :kdb => "kdb"

    def create
      #puts "kdb create"
      self.value=(@resource[:value])
    end

    def destroy
      #puts "kdb destroy"
      kdb ["rm", @resource[:name]]
    end

    def exists?
      #puts "kdb exists? #{self.name}"
      output = execute([command(:kdb), "get", @resource[:name]],
                               :failonfail => false)
      #puts "output: #{output}, #{output.exitstatus}"
      output.exitstatus == 0
    end

    def value 
      #puts "getting value"
      kdb ["sget", "--color=never", @resource[:name], "''"]
    end

    def value=(value)
      #puts "setting value to #{value}"
      kdb(["set", @resource[:name], value])
    end

  end
end
