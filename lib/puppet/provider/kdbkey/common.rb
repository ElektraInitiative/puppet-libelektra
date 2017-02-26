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


end
