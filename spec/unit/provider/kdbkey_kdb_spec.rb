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


TEST_NS = 'user/test/puppet-rspec/'



describe Puppet::Type.type(:kdbkey).provider(:kdb) do

  let(:h) { KdbKeyProviderHelperKDB.new }
  let(:provider) { described_class.new }
  let(:keyname) { "#{TEST_NS}x1" }
  before :example do
    provider.resource = create_resource :name => keyname
  end


  it "should be a child of Puppet::Provider" do
    expect(described_class.new).to be_a_kind_of Puppet::Provider
  end

  context "should check if a key exists" do
    it "should return false on exists? if key is missing" do
      h.ensure_key_is_missing keyname
      expect(provider.exists?).to eq(false)
    end

    it "should return true on exists? if key exists" do
      h.ensure_key_exists keyname
      expect(provider.exists?).to eq(true)
    end
  end

  context "should create key" do
    before :example do
      h.ensure_key_is_missing keyname
    end

    it "with defined name and no value" do
      provider.create
      expect(h.check_key_exists keyname).to eq(true)
      expect(h.key_get_value keyname).to eq("")
    end

    it "with defined name and value" do
      expect(h.check_key_exists keyname).to eq(false)
      provider.resource = create_resource(:name => keyname,
                                          :value => "create with value")
      provider.create
      expect(h.check_key_exists keyname).to eq(true)
      expect(h.key_get_value keyname).to eq("create with value")
    end

    it "with defined name, value and metadata" do
      provider.resource[:value] = "my val"
      provider.resource[:metadata] = {"m1" => "v1", "m2" => "v2"}
      provider.create
      expect(h.check_key_exists keyname).to eq true
      expect(h.key_get_value keyname).to eq "my val"
      expect(h.check_meta_exists keyname, "m1").to eq true
      expect(h.key_get_meta keyname, "m1").to eq "v1"
      expect(h.check_meta_exists keyname, "m2").to eq true
      expect(h.key_get_meta keyname, "m2").to eq "v2"
    end
  end

  context "should update the key value" do
    before :example do
      h.ensure_key_exists keyname, "test"
    end

    it "to an arbitrary string" do
      provider.resource[:value] = "some string value"

      expect(h.key_get_value keyname).to eq("test")
      provider.value= "some string value"
      expect(h.key_get_value keyname).to eq("some string value")
    end

    it "to an empty string" do
      expect(h.key_get_value keyname).to eq("test")
      provider.value= ""
      expect(h.key_get_value keyname).to eq("")
    end
  end

  context "should remove key" do
    before :example do
      h.ensure_key_exists keyname
    end

    it "when key exists" do
      expect(h.check_key_exists keyname).to eq true
      provider.destroy
      expect(h.check_key_exists keyname).to eq false
    end
  end

  context "should get metadata values" do
    before :example do
      h.ensure_meta_exists keyname, "m1", "test"
      h.ensure_meta_exists keyname, "m2", "test"
    end

    it "as a hash" do
      values = provider.metadata
      expect(values).to be_a_kind_of Hash
      expect(values["m1"]).to eq "test"
      expect(values["m2"]).to eq "test"
    end
  end

  context "should update metadata" do
    let(:metadata) { {"m1" => "v1", "m2" => "v2"} }
    before :example do
      h.ensure_key_exists keyname
    end

    it "with missing metadata key" do
      h.ensure_meta_is_missing keyname, "m1"
      h.ensure_meta_is_missing keyname, "m2"
      provider.resource[:metadata] = metadata

      provider.metadata= metadata

      expect(h.check_meta_exists keyname, "m1").to eq true
      expect(h.check_meta_exists keyname, "m2").to eq true
      expect(h.key_get_meta keyname, "m1").to eq "v1"
      expect(h.key_get_meta keyname, "m2").to eq "v2"
    end

    it "with existing metadata" do
      h.ensure_meta_exists keyname, "m1", "test"
      h.ensure_meta_exists keyname, "m2", "test"
      provider.resource[:metadata] = metadata

      provider.metadata= metadata

      expect(h.check_meta_exists keyname, "m1").to eq true
      expect(h.check_meta_exists keyname, "m2").to eq true
      expect(h.key_get_meta keyname, "m1").to eq "v1"
      expect(h.key_get_meta keyname, "m2").to eq "v2"
    end
  end

  context "should purge not specified metadata if 'purge_meta_keys' is set" do
    let(:metadata) { {"m1" => "v1", "m2" => "v2"} }
    before :example do
      provider.resource[:purge_meta_keys] = true

      h.ensure_meta_is_missing keyname, "m1"
      h.ensure_meta_exists keyname, "m2"
      h.ensure_meta_exists keyname, "r1", "to remove"
      h.ensure_meta_exists keyname, "r2", "to remove"
    end

    it "while updating specified" do
      provider.metadata
      provider.metadata = metadata

      expect(h.check_meta_exists keyname, "m1").to eq true
      expect(h.check_meta_exists keyname, "m2").to eq true
      expect(h.key_get_meta keyname, "m1").to eq "v1"
      expect(h.key_get_meta keyname, "m2").to eq "v2"

      #expect(h.check_meta_exists keyname, "r1").to eq false
      #expect(h.check_meta_exists keyname, "r2").to eq false
      expect(h.key_get_meta keyname, "r1").to eq ""
      expect(h.key_get_meta keyname, "r2").to eq ""
    end

    # we can't test is this way, as we can not set 'internal' metadata
    # values
    #it "while ignoring meta keys starting with 'internal/'" do
    #  h.ensure_meta_exists keyname, "internal/puppet/test", "keep it"

    #  puts provider.metadata
    #  provider.metadata = metadata

    #  expect(h.check_meta_exists keyname, "m1").to eq true
    #  expect(h.check_meta_exists keyname, "m2").to eq true

    #  expect(h.check_meta_exists keyname, "internal/puppet/test").to eq true
    #  expect(h.key_get_meta keyname, "internal/puppet/test").to eq "keep it"

    #  #expect(h.check_meta_exists keyname, "r1").to eq false
    #  #expect(h.check_meta_exists keyname, "r2").to eq false
    #  expect(h.key_get_meta keyname, "r1").to eq ""
    #  expect(h.key_get_meta keyname, "r2").to eq ""
    #end

    it "while ignoring comments, which are not modified" do
      h.ensure_comment_exists keyname, " some comments"

      provider.metadata
      provider.metadata = metadata

      #expect(check_meta_exists keyname, COMMENT+"/#0").to eq true
      expect(h.check_comment_exists keyname).to eq true

      #expect(h.key_get_meta keyname, COMMENT+"/#0").to eq "# some comments"
      expect(h.key_get_comment keyname).to eq " some comments"
    end

    it "while ignoring commens which are added too" do
      provider.metadata = metadata
      provider.comments = "comment defined by me"

      provider.metadata
      provider.metadata = metadata

      expect(h.check_comment_exists keyname).to eq true
      #expect(h.check_meta_exists keyname, "r1").to eq false
      expect(h.key_get_meta keyname, "r1").to eq ""
    end

    it "while ignoring 'order' metadata" do
      h.ensure_meta_exists keyname, "order", "5"

      provider.metadata
      provider.metadata = metadata

      expect(h.check_meta_exists keyname, "order").to eq true
      expect(h.key_get_meta keyname, "order").to eq "5"
      #expect(h.check_meta_exists keyname, "r1").to eq false
      expect(h.key_get_meta keyname, "r1").to eq ""
    end
  end

  context "should handle comments" do
    it "and fetch the comment string" do
      h.ensure_comment_exists keyname, "some comments"

      comments = provider.comments

      expect(comments).to be_a_kind_of String
      expect(comments).to eq "some comments"
    end

    it "and fetch a multiline the comment string at once" do
      expected_comment = <<EOT
 this is a multi
 line
 comment
EOT
      expected_comment.chomp!

      h.ensure_comment_exists keyname, expected_comment

      comments = provider.comments

      expect(comments).to eq expected_comment
    end

    it "and create a new comment" do
      h.ensure_comment_is_missing keyname

      provider.comments= "a new comment"

      expect(h.check_comment_exists keyname).to eq true

      # for now, as we cannot remove metakeys, we have to live with
      # empty comment lines
      actual_comment = h.key_get_comment(keyname).gsub(/\n*$/, '')

      expect(actual_comment).to eq "a new comment"
    end

    it "and update a multi line comment" do
      h.ensure_comment_exists keyname

      expected_comment = <<EOT
 this is a multi line 
 comment
EOT
      expected_comment.chomp!

      provider.comments= expected_comment

      actual_comment = h.key_get_comment(keyname).gsub(/\n*$/, '')
      expect(actual_comment).to eq expected_comment
    end

  end
end
