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
require_relative 'key_ruby_helper.rb'
require 'kdb'


describe Puppet::Type.type(:kdbkey).provider(:ruby) do

  let(:h) { KdbKeyProviderHelper.new 'user/test/puppet-rspec/'}
  let(:keyname) { "#{h.test_prefix}x1" }
  #let(:ks) { Kdb::KeySet.new }
  let(:provider) { described_class.new }

  before :example do
    provider.use_fake_ks h.ks
    provider.resource = create_resource :name => keyname
  end

  it_behaves_like "a kdbkey provider"

end
