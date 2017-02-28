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

require 'puppet/provider/kdbkey/common.rb'

describe Puppet::Provider::KdbKeyCommon do
  let(:provider) { described_class.new }

  RSpec.shared_examples "key => spec-key" do |keyname, expected|
    it "for key '#{keyname}'" do
      provider.resource = create_resource :name => keyname
      expect(
        provider.get_spec_key_name
      ).to eq expected
    end
  end

  context "should get corresponding spec-key from key name" do
    include_examples "key => spec-key", "system/x1/x2", "spec/x1/x2"
    include_examples "key => spec-key", "user/x1/x2", "spec/x1/x2"
    include_examples "key => spec-key", "/x1/x2", "spec/x1/x2"
    include_examples "key => spec-key", "dir/x1/x2", "spec/x1/x2"
    include_examples "key => spec-key", "system/x1", "spec/x1"
    include_examples "key => spec-key", "system/\\some\\/escaped/x1",
                                        "spec/\\some\\/escaped/x1"
  end


end
