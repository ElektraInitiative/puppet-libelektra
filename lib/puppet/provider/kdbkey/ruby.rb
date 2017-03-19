# encoding: UTF-8
##
# @file
#
# @brief Ruby provider for type kdbkey for managing libelektra keys
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

require 'puppet/provider/kdbkey/common'

module Puppet
  Type.type(:kdbkey).provide :ruby, :parent => Puppet::Provider::KdbKeyCommon do
    desc "kdb through libelektra Ruby API"

    # static class var for checking if we are able to use this provider
    @@have_kdb = true
    @@is_fake_ks = false

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
    # since there is not suitable way to a propper provider instance
    # cleanup.
    # The flush method is only called, if the underlaying resource was
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

    def create
      @resource_key = Kdb::Key.new @resource[:name], value: @resource[:value]
      self.check= @resource[:check] unless @resource[:check].nil?
      self.metadata= @resource[:metadata] unless @resource[:metadata].nil?
      self.comments= @resource[:comments] unless @resource[:comments].nil?
      @ks << @resource_key
    end

    def destroy
      @ks.delete @resource[:name] unless @resource_key.nil?
    end

    # is called first for each managed resource
    # stores the queried key for later modifications
    def exists?
      Puppet.debug "kdbkey/ruby exists? #{@resource[:name]}"

      # this is the first method call for a managed resource
      # so, here we have to do a kdb.open
      # all opend kdb objects are used by later methods so keep them
      #
      # note: for the moment we do a kdb.open/get/set for EACH managed
      # kdbkey resource separately. This results in a opened kdb handle
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
      begin
        @kdb_handle = Kdb.open
        @@open_handles << @kdb_handle
        @ks = Kdb::KeySet.new
        @cascading_key = @resource[:name].gsub(/^\w+\//, '/')
        puts "do kdb.get ks, #{@cascading_key}" if @verbose
        @kdb_handle.get @ks, @cascading_key
        @ks.pretty_print if @verbose
      end unless @is_fake_ks
      @resource_key = @ks.lookup @resource[:name]
      puts "resource key nil? #{@resource_key.nil?}" if @verbose
      return !@resource_key.nil?
    end

    def value
      return @resource_key.value unless @resource_key.nil?
    end

    def value=(value)
      @resource_key.value= value unless @resource_key.nil?
    end

    # get metadata values as Hash
    # note: in order to not trigger an refresh cycle, we have to be careful which
    # keys should be returned. It 'purge_meta_keys?' is not set, we have to remove
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
        if /^(comments?)\/#/ =~ e.name
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
        #@resource_key.set_meta "#{@comments_key_name}/##{index + 1}", "##{line}"
        @resource_key.set_meta "#{@comments_key_name}/##{index}", "##{line}"
      end
      #@resource_key.set_meta "#{@comments_key_name}/#0", ''

      # iterate over all meta keys and remove all comment keys which
      # represent a comment line, which does not exist any more
      @resource_key.meta.each do |e|
        if e.name.match(/^#{@comments_key_name}\/#(\d+)$/)
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
            if /^(\w+)\/#\d+$/ =~ check_name
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
      end

      # remove all not specified meta keys from spec_key starting with 'check'
      spec_key.meta.each do |e|
        if e.name.start_with? "check" and !spec_to_set.include? e.name
          spec_key.del_meta e.name
        end
      end
    end


    # flush is call if a resource was modified
    # thus this method is perfectly suitable for our db.set method which will
    # finally bring the changes to disk
    # also do a kdbclose for this handle
    def flush
      unless @is_fake_ks
        Puppet.debug "kdbkey/ruby: flush #{@resource[:name]}"
        @kdb_handle.set @ks, @cascading_key
        @@open_handles.delete @kdb_handle
        @kdb_handle.close
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
