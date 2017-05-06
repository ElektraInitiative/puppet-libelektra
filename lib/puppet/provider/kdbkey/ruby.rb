# encoding: UTF-8
##
# @file
#
# @brief Ruby provider for type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#
require 'etc'
require 'puppet/provider/kdbkey/common'

module Puppet
  Type.type(:kdbkey).provide :ruby, :parent => Puppet::Provider::KdbKeyCommon do
    desc "kdb through libelektra Ruby API"

    # static class var for checking if we are able to use this provider
    @@have_kdb = true
    @@is_fake_ks = false

    has_feature :user

    begin
      # load libelektra Ruby binding extension
      require 'kdb'
    rescue LoadError
      @@have_kdb = false
    end

    # make this provider always to be default (aslong it is useable
    #defaultfor :kernel => :Linux
    def self.default?
      @@have_kdb
    end
    # if we can load the 'kdb' extension
    confine :true => @@have_kdb

    # remember all opened kdb handles
    # since there is not suitable way to a proper provider instance
    # cleanup.
    # The flush method is only called, if the underlying resource was
    # modified.
    # All opened handles will be closed on 'self.post_resource_eval'
    # which is done once per provider class.
    @@open_handles = []

    # just used during testing to inject a mock
    def use_fake_ks(ks)
      @ks = ks
      @is_fake_ks = true
    end

    # allow access to internal key, used during testing
    attr_reader :resource_key


    def do_asuser(proc_obj)
      unless @resource[:user].nil?
        Puppet::Util::SUIDManager.asuser(@resource[:user]) do

          old_user = ENV['USER']
          old_home = ENV['HOME']
          old_xdg = ENV['XDG_CONFIG_HOME']

          if @resource[:user] =~ /^\d+/
            # we got a numeric user argument try to convert to user name
            begin
              user = Etc.getpwuid(@resource[:user].to_i).name
            rescue
              user = @resource[:user]
            end
          else
            user = @resource[:user]
          end

          ENV['USER'] = user
          begin
            # if passwd entry for user does not exist, this will trigger an
            # ArgumentError
            ENV['HOME'] = Etc.getpwnam(user).dir
          rescue
            ENV['HOME'] = ''
          end

          ENV['XDG_CONFIG_HOME'] = ''

          begin
            Puppet.debug("do_asuser: euid: #{Process.euid} " +
                         "user: #{@resource[:user]} " +
                         "HOME: #{ENV['HOME']} " +
                         "USER: #{ENV['USER']} ")
            proc_obj.call
          rescue
            ENV['USER'] = old_user
            ENV['HOME'] = old_home
            ENV['XDG_CONFIG_HOME'] = old_xdg
          end
        end
      else
        proc_obj.call
      end

    end

    def create
      @resource_key = Kdb::Key.new @resource[:name]
      self.value= @resource[:value] unless @resource[:value].nil?
      self.check= @resource[:check] unless @resource[:check].nil?
      self.metadata= @resource[:metadata] unless @resource[:metadata].nil?
      self.comments= @resource[:comments] unless @resource[:comments].nil?
      @ks << @resource_key
    end

    def destroy
      @ks.delete @resource[:name] unless @resource_key.nil?
      # check if there are array keys left
      @ks.each do |x|
        if x.name =~ /^#{@resource[:name]}\/#_*\d+$/
          @ks.delete x
        end
      end
    end

    # is called first for each managed resource
    # stores the queried key for later modifications
    def exists?
      Puppet.debug "kdbkey/ruby exists? #{@resource[:name]}"

      # this is the first method call for a managed resource
      # so, here we have to do a kdb.open
      # all opened kdb objects are used by later methods so keep them
      #
      # note: for the moment we do a kdb.open/get/set for EACH managed
      # kdbkey resource separately. This results in an opened kdb handle
      # and keySet for each manged key. This strategy is required, since
      # we might have modified the underlying Elektra key space
      # (a changed/added mountpoint after the actual kdb.open).
      #
      # It would be better if we could share our handles and keysets, but:
      # - one shared handle and keyset is definitely too less, for the following reasons
      #   - actually there is no way to guarantee that all kdbmount modifications happen
      #     BEFORE the first kdb.open call
      #   - since we not really know here, which resource keys we have to manage, we end
      #     up with fetching the whole Elektra key space, which would be way too much
      # - a better strategy would be to use one handle and keyset per mountpoint. But for
      #   the moment this is too complicated (e.g. how to proceed with cascading keys?)
      #
      open_proc = Proc.new do
        @kdb_handle = Kdb.open
        @@open_handles << @kdb_handle
        @ks = Kdb::KeySet.new
        @cascading_key = Kdb::Key.new @resource[:name].gsub(/^\w+\//, '/')
        puts "do kdb.get ks, #{@cascading_key.name}" if @verbose
        @kdb_handle.get @ks, @cascading_key
        Puppet.debug "reading from config file '#{@cascading_key.value}'"
        @ks.pretty_print if @verbose
      end

      unless @is_fake_ks
        do_asuser open_proc
      end

      @resource_key = @ks.lookup @resource[:name]
      puts "resource key nil? #{@resource_key.nil?}" if @verbose
      return !@resource_key.nil?
    end

    def value
      return nil if @resource_key.nil?
      return [@resource_key.value] if @ks.lookup("#{@resource_key.name}/#0").nil?

      # array value
      value = []
      @ks.each do |x| 
        if x.name =~ /^#{@resource_key.name}\/#_*\d+$/
          value << x.value
        end
      end
      value
    end

    def value=(value)
      if @resource_key.nil?
        return
      end

      remove_from_this_index = 0
      if not value.is_a? Array
        @resource_key.value= value.to_s

      elsif value.size == 1
        @resource_key.value= value[0].to_s

      else
        @resource_key.value= ''
        value.each_with_index do |elem_value, index|
          elem_key_name = array_key_name @resource_key.name, index
          elem_key = @ks.lookup elem_key_name
          if elem_key.nil?
            elem_key = Kdb::Key.new elem_key_name
            @ks << elem_key
          end
          elem_key.value= elem_value.to_s
        end
        remove_from_this_index = value.size
      end

      # remove possible "old" array keys
      i = remove_from_this_index
      while not (key = @ks.lookup(array_key_name @resource_key.name, i)).nil?
        i += 1
        @ks.delete key
      end
    end

    # get metadata values as Hash
    # note: in order not to trigger an refresh cycle, we have to be careful which
    # keys should be returned. If 'purge_meta_keys?' is not set, we have to remove
    # the not-specified metakeys from the result set.
    def metadata
      #key.meta.to_h unless key.nil? ruby 1.9 does not have Enumerable.to_h :(
      res = Hash.new
      @resource_key.meta.each do |e|
        next if skip_this_metakey? e.name, true

        # if purge_meta_keys is NOT set to true, remove all unspecified keys
        # otherwise, Puppet will think we have to change something, so just
        # keep those, which might have to be changed
        unless @resource.purge_meta_keys? or @resource[:metadata].nil?
          next unless @resource[:metadata].include? e.name
        end

        res[e.name] = e.value
      end unless @resource_key.nil?

      return res
    end

    # set metadata values
    # if 'purge_meta_keys?' == true, also remove all not specified keys but not
    # too much (keeping internal ones)
    def metadata=(value)
      # update metadata
      value.each { |k, v|
        @resource_key.set_meta k, v
      } unless @resource_key.nil?

      # do we have to purge all unspecified keys?
      if @resource.purge_meta_keys?
        @resource_key.meta.each do |metakey|
          next if skip_this_metakey? metakey.name

          @resource_key.del_meta metakey.name unless value.include? metakey.name
        end
      end
    end

    # currently Elektra plugins implement a not consistent way of specifying
    # comments. So store the used metakey name to use the same one when writing the
    # comments. see https://github.com/ElektraInitiative/libelektra/issues/1375
    @comments_key_name = "comments"

    # get key comments as one string
    # merge the Elektra 'comments?/#' array
    def comments
      comments = ""
      first = true # used for splitting lines
      # search for all meta keys which names starts with 'comments/#'
      # and concat its values line by line
      @resource_key.meta.each do |e|
        if /^(comments?)\/#_*\d+$/ =~ e.name
          puts "update comments key name to #{$1}" if @verbose
          @comments_key_name = $1
          comments << "\n" unless first
          comments << e.value.sub(/^# ?/, '')
          first = false
        end
      end
      return comments
    end

    # update comments
    #
    def comments=(value)
      # why do we have to init this inst var again???
      @comments_key_name ||= "comments"
      # split specified comment into lines
      comment_lines = value.split "\n"
      # update all comment lines
      comment_lines.each_with_index do |line, index|
        puts "comments keyname: #{@comments_key_name}" if @verbose
        # currently hosts plugin treats #0 comment as inline comment
        #@resource_key.set_meta array_key_name(@comments_key_name, index + 1), "##{line}"
        @resource_key.set_meta array_key_name(@comments_key_name, index), "##{line}"
      end
      #@resource_key.set_meta "#{@comments_key_name}/#0", ''

      # iterate over all meta keys and remove all comment keys which
      # represent a comment line, which does not exist any more
      @resource_key.meta.each do |e|
        if e.name.match(/^#{@comments_key_name}\/#_*(\d+)$/)
          index = $1.to_i
          if comment_lines[index].nil?
            @resource_key.del_meta e.name
          end
        end
      end

      # the (old) ini plugin comments strategy uses a 'comments' metakey
      # to store the last comments array index. This has to be updated.
      if comment_lines.size > 0 and @comments_key_name == "comments"
        @resource_key.set_meta "comments", "##{comment_lines.size - 1}"
      else
        @resource_key.del_meta "comments"
      end
      @resource_key.pretty_print if @verbose
    end

    # get all 'check/*' meta keys of the corresponding 'spec/' key
    #
    def check
      spec_hash = {}
      spec_key = @ks.lookup get_spec_key_name
      unless spec_key.nil?
        spec_key.meta.each do |m|
          if /^check\/(.*)$/ =~ m.name
            check_name = $1
            if /^(\w+)\/#_*\d+$/ =~ check_name
              spec_hash[$1] = [] unless spec_hash[$1].is_a? Array
              spec_hash[$1] << m.value
            else
              spec_hash[check_name] = m.value
            end
          end
        end
      end
      # special case: if we get just one key and its value
      # is "", return this as a string
      if spec_hash.size == 1 and spec_hash.values[0] == ""
        spec_hash = spec_hash.keys[0]
      end
      return spec_hash
    end

    # update 'check/*' meta data on the corresponding 'spec/' key
    #
    def check=(value)
      Puppet.debug "setting spec: #{value}"
      spec_key = Kdb::Key.new get_spec_key_name

      if @ks.lookup(spec_key).nil?
        @ks << spec_key
      else
        spec_key = @ks.lookup spec_key
      end

      spec_to_set = specified_checks_to_meta value

      # set meta data on spec_key
      spec_to_set.each do |spec_name, spec_value|
        spec_key[spec_name] = spec_value
        # also add the check meta data to resource_key directly, they will get
        # removed by the 'spec' plugin (if the plugin placement bug is fixed ;)
        # This is required, since the check is only evaluated if the key has the
        # appropriate metadata attached. If the spec_key is created with the same
        # keyset, the resources value will be set before the check can be performed
        # so we might end up with an invalid value for the setting.
        @resource_key[spec_name] = spec_value
      end

      # remove all not specified meta keys from spec_key starting with 'check'
      spec_key.meta.each do |e|
        if e.name.start_with? "check" and !spec_to_set.include? e.name
          spec_key.del_meta e.name
          # perform same operation on resource_key
          @resource_key.del_meta e.name
        end
      end
    end

    # generate an error string from a Kdb::Key
    def key_get_error_msg(key)
      return nil unless key.is_a? Kdb::Key

      msg = ""
      if key.has_meta? 'error'
        msg += key['error/description'] + "\n"
        msg += "Reason: #{key['error/reason']}\n"
        msg += "Error number: ##{key['error/number']}\n"
        msg += "Module: #{key['error/module']}\n"
        msg += "Configfile: #{key['error/configfile']}\n"
        msg += "Mountpoint: #{key['error/mountpoint']}\n"
      end
      return msg
    end


    # flush is call if a resource was modified
    # thus this method is perfectly suitable for our db.set method which will
    # finally bring the changes to disk
    # also do a kdbclose for this handle
    def flush
      close_proc = Proc.new do
        begin
          Puppet.debug "kdbkey/ruby: flush #{@resource[:name]}"
          @kdb_handle.set @ks, @cascading_key
        rescue
          # we only care about the error message here, warnings could be
          # misleading, especially if they do not concern the key we are
          # manipulating
          raise Puppet::Error.new key_get_error_msg(@cascading_key)
        ensure
          @@open_handles.delete @kdb_handle
          @kdb_handle.close
        end
      end

      unless @is_fake_ks
        do_asuser close_proc
      end
    end

    # provider de-init hook
    # this is our last chance to close remaining kdb handles
    def self.post_resource_eval
      Puppet.debug "kdbkey/ruby: closing kdb db"
      @@open_handles.delete_if do |handle|
        handle.close
        true
      end
    end

  end
end
