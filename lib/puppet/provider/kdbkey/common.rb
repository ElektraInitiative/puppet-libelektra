# encoding: UTF-8
##
# @file
#
# @brief common functions for all kdbkey provider
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#
#

class Puppet::Provider::KdbKeyCommon < Puppet::Provider

    # just used for debugging
    attr_accessor :verbose
    @verbose = false


    def skip_this_metakey?(metakey, keep_if_specified = false)
      # skip modifing these keys at all times (even if user wants to)
      return true if metakey.start_with? "internal/"

      # if user specifies these meta keys, let them do so
      unless @resource[:metadata].nil?
        unless keep_if_specified and @resource[:metadata].include? metakey
          return true if metakey == "order"
          return true if /^comments?\/#/ =~ metakey or metakey == "comments"
        end
      end
      return false
    end

    def is_special_meta_key?(metakey)
      return true if metakey.start_with? "internal/"
      return true if metakey.start_with? "comment"
      return true if metakey == "order"
      return false
    end

    def get_spec_key_name(keyname = @resource[:name])
      return keyname.gsub(/^\w*\//, "spec/")
    end

    def specified_checks_to_meta(value)
      # ensure we have a Hash
      value = {value => ""} if value.is_a? String

      spec_to_set = {}
      value.each do |check_key, check_value|
        if check_value.is_a? Array
          # if value is an Array define an Elektra array
          check_value.each_with_index do |v, index|
            spec_to_set["check/#{check_key}/##{index}"] = v
          end
        else
          spec_to_set["check/#{check_key}"] = check_value
        end
      end
      spec_to_set
    end


end
