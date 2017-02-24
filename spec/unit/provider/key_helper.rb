# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

# currently metadaa key for comments used by ini
# but hosts uses 'comment'
COMMENT = 'comments'


def create_resource(params)
  Puppet::Type.type(:kdbkey).new(params)
end


