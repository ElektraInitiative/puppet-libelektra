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
      self.metadata= @resource[:metadata] unless @resource[:metadata].nil?
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

    def metadata
      @metadata_values = {}
      output = run_kdb ["lsmeta", @resource[:name]]
      output.split.each do |metaname|
        # foreach meta key, fetch its value
        gm = run_kdb(["getmeta", @resource[:name], metaname], {
          :combine    => false,
          :failonfail => false}
        )
        if gm.exitstatus == 0
          @metadata_values[metaname.strip] = gm.chomp
        end
      end
      return @metadata_values
    end

    def metadata=(value)
      value.each do |metaname, metavalue|
        run_kdb ["setmeta", @resource[:name], metaname, metavalue]
      end
      # handle purge_meta_keys
      if @resource.purge_meta_keys? and @metadata_values.is_a? Hash
        @metadata_values.each do |m,v|
          next if value.include? m
          next if m == "comments" or m.start_with? "comment/", "comments/"
          next if m.start_with? "internal/"
          next if m == "order"

          # currently there is no rmmeta command for kdb
          run_kdb ["setmeta", @resource[:name], m, '']
        end
      end
    end


  end
end
