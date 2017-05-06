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
  subject { described_class.new }

  RSpec.shared_examples "key => spec-key" do |keyname, expected|
    it "for key '#{keyname}'" do
      subject.resource = create_resource :name => keyname
      expect(
        subject.get_spec_key_name
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



  RSpec.shared_examples "array element index" do |index, expected|
    it "for index element #{index}" do
      expect(subject.array_key_name keyname, index).to eq "#{keyname}/#{expected}"
    end
  end

  context "should get correct elektra array key names" do
    let(:keyname) { "system/sw/test" }

    include_examples "array element index", 0,      "#0"
    include_examples "array element index", 1,      "#1"
    include_examples "array element index", 9,      "#9"
    include_examples "array element index", 10,     "#_10"
    include_examples "array element index", 11,     "#_11"
    include_examples "array element index", 19,     "#_19"
    include_examples "array element index", 20,     "#_20"
    include_examples "array element index", 90,     "#_90"
    include_examples "array element index", 100,    "#__100"
    include_examples "array element index", 286,    "#__286"
    include_examples "array element index", 1000,   "#___1000"
    include_examples "array element index", 10000,  "#____10000"
    include_examples "array element index", 100000, "#_____100000"
  end


end
