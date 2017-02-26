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
  Type.type(:kdbkey).provide :kdb, :parent => Puppet::Provider::KdbKeyCommon do
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
        # skip internal keys
        next if skip_this_metakey? metaname, true
        # skip this metakey, if purge meta keys is NOT set and this
        # key is not specified by the user
        unless @resource.purge_meta_keys? or @resource[:metadata].nil?
          next unless @resource[:metadata].include? metaname
        end

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

    def comments
      metadata unless @metadata_values.is_a? Hash
      comments = ""
      @metadata_values.each do |meta, value|
        if /^comments?\/#/ =~ meta
          comments << "\n" unless comments.empty?
          comments << value.sub(/^#/, '')
        end
      end
      return comments
    end

    def comments=(value)
      metadata unless @metadata_values.is_a? Hash
      comment_lines = value.split "\n"

      updated = []
      comment_lines.each_with_index do |line, index|
        updated << meta_name = "comments/##{index}"
        run_kdb ["setmeta", @resource[:name], meta_name, line]
      end

      @metadata_values.each do |k, v|
        # update comments count value
        if k == "comments"
          run_kdb ["setmeta", @resource[:name], k, "##{comment_lines.size}"]
        end

        if k.start_with? "comments/#" and !updated.include? k
          run_kdb ["setmeta", @resource[:name], k, '']
        end
      end
    end


  end
end
