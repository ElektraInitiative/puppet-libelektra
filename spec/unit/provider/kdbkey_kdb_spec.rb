# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

require 'spec_helper'
require_relative 'key_helper.rb'
require_relative 'key_kdb_helper.rb'
require 'kdb'


describe Puppet::Type.type(:kdbkey).provider(:kdb) do

  let(:h) { KdbKeyProviderHelperKDB.new 'user/test/puppet-rspec/' }
  let(:provider) { described_class.new }
  let(:keyname) { "#{h.test_prefix}x1" }
  before :example do
    provider.resource = create_resource :name => keyname
  end

  it_behaves_like "a kdbkey provider", true
end
