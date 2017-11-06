# encoding: UTF-8
##
# @file
#
# @brief Kdb provider for type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

require_relative 'common'
require 'tempfile'

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
      self.value= @resource[:value]
      self.check= @resource[:check] unless @resource[:check].nil?
      self.metadata= @resource[:metadata] unless @resource[:metadata].nil?
      self.comments= @resource[:comments] unless @resource[:comments].nil?
    end

    def destroy
      run_kdb ["rm", @resource[:name]]
      # remove possible array elements
      list_keys.each do |x|
        if x =~ /#{@resource[:name]}\/#_*\d+/
          run_kdb ["rm", x]
        end
      end
    end

    def exists?
      Puppet.debug "kdbkey/kdb exists? #{@resource[:name]}"
      output = execute([command(:kdb), "get", @resource[:name]],
                               :failonfail => false)
      output.exitstatus == 0
    end

    def list_keys
      output = run_kdb ["ls", "--color=never", @resource[:name]]
      return output.split
    end

    def value
      elems = list_keys

      unless elems.include? "#{@resource[:name]}/#0"
        # single value key
        return [get_key_value(@resource[:name])]
      else
        # Array key
        value = []
        elems.select do |x|
          x =~ /^#{@resource[:name]}\/#_*\d+$/
        end.each do |x|
          value << get_key_value(x)
        end
        return value
      end

    end

    def get_key_value(key)
      return run_kdb ["sget", "--color=never", key, "''"]
    end

    def value=(value)
      remove_from_this_index = 0
      if not value.is_a? Array
        set_key_value @resource[:name], value

      elsif value.size == 1
        set_key_value @resource[:name], value[0]

      else
        set_key_value @resource[:name], ''
        value.each_with_index do |elem_value, index|
          set_key_value array_key_name(@resource[:name], index), elem_value
        end
        remove_from_this_index = value.size
      end
      # remove possible "old" array keys
      output = run_kdb ["ls", "--color=never", @resource[:name]]
      output.split.each do |x|
        if x =~ /^#{@resource[:name]}\/#(\d+)$/
          index = $1.to_i
          if index >= remove_from_this_index
            run_kdb ['rm', x]
          end
        end
      end
    end

    def set_key_value(key, value)
      run_kdb ["set", key, value]
    end

    def read_metadata_values
      read_metadata_values_from_key @resource[:name]
    end

    def read_metadata_values_from_key(key_to_read_from)
      puts "read meta data from key '#{key_to_read_from}'" if @verbose
      @metadata_values = {}
      Tempfile.open("key") do |file|
        run_kdb ["export", key_to_read_from, "ni", file.path]
        # reopen file
        file.open
        metadata_reached = false
        file.each do |line|
          line.chomp!
          puts "read meta: '#{line}'" if @verbose
          if line == "[]"
            metadata_reached = true
            next
          end
          next if metadata_reached == false
          # end of metadata reached
          break if line.empty?

          key_name, key_value = line.split(" = ")
          key_name.strip!

          puts "use meta: '#{key_name}' => '#{key_value}'" if @verbose
          @metadata_values[key_name] = key_value.to_s # ensure we have a string
        end
        file.close!
      end
      return @metadata_values
    end

    def metadata
      read_metadata_values unless @metadata_values.is_a? Hash
      ret = @metadata_values.reject do |k,v|
        # do not keep this key_name
        delete = (
          # if it is an internal key (unless specified)
          skip_this_metakey?(k, true) or
          # or unless purge_meta_keys == true or k is specified
          not(
            @resource[:metadata].nil? or @resource.purge_meta_keys? or
            @resource[:metadata].include? k
          )
        )
        delete
      end
      puts "metadata is: #{ret}" if @verbose
      ret
    end

    def metadata=(value)
      read_metadata_values unless @metadata_values.is_a? Hash
      puts "having metadata: #{@metadata_values}" if @verbose
      value.each do |k,v|
        @metadata_values[k] = v
      end
      if @resource.purge_meta_keys?
        @metadata_values.keep_if do |k,v|
          keep = (@resource[:metadata].include?(k) or is_special_meta_key?(k))
          puts "keep this meta: '#{k}' #{keep}" if @verbose
          keep
        end
      end
      puts "updated metadata: #{@metadata_values}" if @verbose
    end

    def comments
      read_metadata_values unless @metadata_values.is_a? Hash
      comments = {}
      @metadata_values.each do |meta, value|
        if /^comments?\/#(\d+)/ =~ meta
          value = value[1..-1] if value[0] == '"'
          value = value[0..-2] if value[-1] == '"'
          comments[$1] = value.sub(/^#/, '')
        end
      end
      # we get a hash, with
      #  #num => line
      # so sort by #num, take the lines and join with newline
      comments = comments.sort_by{|k,v| k}.map{|e|e[1]}.join "\n"
      comments
    end

    def comments=(value)
      self.metadata unless @metadata_values.is_a? Hash
      comment_lines = value.split "\n"

      # remove all comment meta keys
      @metadata_values.delete_if { |k,v| k.start_with? "comment" }

      @metadata_values["comments"] = "##{comment_lines.size}"
      comment_lines.each_with_index do |line, index|
        @metadata_values[array_key_name "comments", index] = line
      end
    end

    def check
      @spec_meta_values = read_metadata_values_from_key(get_spec_key_name)
      specs = {}
      @spec_meta_values.each do |k,v|
        # we are interested in meta keys starging with 'check/'
        if /^check\/(.*)$/ =~ k
          check_name = $1
          # if it is an elektra Array, convert it to a Ruby array
          # while preserve order
          if /^(\w+)\/#(\d+)$/ =~ check_name
            check_name, index = $1, $2.to_i
            specs[check_name] = [] unless specs[check_name].is_a? Array
            specs[check_name][index] = v
          else
            specs[check_name] = v
          end
        end
      end
      if specs.size == 1 and specs.values[0].to_s.empty?
        specs = specs.keys[0]
      end
      puts "spec_keys: #{specs}" if @verbose
      return specs
    end

    def check=(value)
      self.check unless @spec_meta_values.is_a? Hash

      spec_to_set = specified_checks_to_meta value
      @spec_meta_values.merge! spec_to_set
      @spec_meta_values.delete_if do |k,v|
        (k.start_with? "check" and not spec_to_set.include? k)
      end
      Tempfile.open("speckey") do |file|
        file.puts
        file.puts " = "
        file.puts
        file.puts "[]"
        @spec_meta_values.each do |k,v|
          file.puts " #{k} = #{v}"
        end
        file.flush
        begin
          file.rewind
          file.each do |line|
            puts "import spec: #{line}"
          end
        end if @verbose
        file.close
        run_kdb ["import", get_spec_key_name, "ni", file.path]
        file.unlink
      end
    end

    def flush
      return unless @metadata_values.is_a? Hash
      Tempfile.open("key") do |file|
        file.puts
        if not @resource[:value].is_a? Array
          file.puts " = #{@resource[:value]}"
        else
          file.puts " = #{@resource[:value][0]}"
        end
        file.puts
        file.puts "[]"
        @metadata_values.each do |k,v|
          file.puts " #{k} = #{v}"
        end
        file.flush
        begin
          file.rewind
          file.each do |line|
            puts "import: #{line}"
          end
        end if @verbose
        file.close
        run_kdb ["import", @resource[:name], "ni", file.path]
        file.unlink
      end
    end
  end
end
