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

    has_feature :user

    commands :kdb => "kdb"

    def run_kdb(args, params = {:combine => true, :failonfail => true})
      cmd_line = [command(:kdb)] + args
      params[:uid] = @resource[:user] unless @resource[:user].nil?
      execute(cmd_line, params)
    end

    def create
      self.value=(@resource[:value])
    end

    def destroy
      run_kdb ["rm", @resource[:name]]
    end

    def exists?
      Puppet.debug "kdbkey/kdb exists? #{@resource[:name]}"
      output = execute([command(:kdb), "get", @resource[:name]],
                               :failonfail => false)
      #puts "output: #{output}, #{output.exitstatus}"
      output.exitstatus == 0
    end

    def value 
      run_kdb ["sget", "--color=never", @resource[:name], "''"]
    end

    def value=(value)
      run_kdb ["set", @resource[:name], value]
    end

  end
end
