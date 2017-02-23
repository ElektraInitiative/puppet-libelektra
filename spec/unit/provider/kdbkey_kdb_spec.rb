# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

require 'spec_helper'
require 'kdb'

TEST_NS = 'user/test/puppet-rspec/'
# currently metadaa key for comments used by ini
# but hosts uses 'comment'
COMMENT = 'comments'


def create_resource(params)
  Puppet::Type.type(:kdbkey).new(params)
end

def do_on_kdb
  raise ArgumentError, "block required" unless block_given?

  Kdb.open do |kdb|
    ks = Kdb::KeySet.new
    kdb.get ks, TEST_NS
    yield ks
    kdb.set ks, TEST_NS
  end
end

def do_on_kdb_with_key(keyname)
  raise ArgumentError, "block required" unless block_given?
  do_on_kdb do |ks|
    yield ks.lookup(keyname)
  end
end


def ensure_key_exists(keyname, value = "test")
  do_on_kdb do |ks|
    key = ks.lookup(keyname)
    if key.nil?
      ks << Kdb::Key.new(keyname, value: value)
    else
      key.value = value
    end
  end
end

def ensure_meta_exists(keyname, meta, value = "test")
  do_on_kdb do |ks|
    key = ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new(keyname)
      ks << key
    end
    key.set_meta meta, value
  end
end

def ensure_comment_exists(keyname, comment = "test")
  do_on_kdb do |ks|
    key = ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new keyname
      ks << key
    end
    lines = comment.split "\n"
    key[COMMENT] = "##{lines.size}"
    lines.each_with_index do |line, index|
      key[COMMENT+"/##{index}"] = line
    end
  end
end

def ensure_key_is_missing(keyname)
  do_on_kdb do |ks|
    unless ks.lookup(keyname).nil?
      ks.delete keyname
    end
  end
end

def ensure_meta_is_missing(keyname, meta)
  do_on_kdb_with_key keyname do |key|
    key.del_meta meta unless key.nil? 
  end
end

def ensure_comment_is_missing(keyname)
  do_on_kdb_with_key keyname do |key|
    unless key.nil?
      key.meta.each do |m|
        key.del_meta m if m.name.start_with? COMMENT
      end
    end
  end
end

def check_key_exists(name)
  missing = false
  do_on_kdb do |ks|
    missing = ks.lookup(name).nil?
  end
  return !missing
end

def check_meta_exists(keyname, meta)
  exists = false
  do_on_kdb_with_key keyname do |key|
    exists = key.has_meta? meta unless key.nil?
  end
  return exists
end

def check_comment_exists(keyname)
  exists = false
  do_on_kdb_with_key keyname do |key|
    exists = key.has_meta?(COMMENT) or key.has_meta?(COMMENT+"/#0") unless key.nil?
  end
  return exists
end

def key_get_value(keyname)
  value = nil
  do_on_kdb_with_key keyname do |key|
    value = key.value unless key.nil?
  end
  return value
end

def key_get_meta(keyname, meta)
  value = nil
  do_on_kdb_with_key keyname do |key|
    value = key[meta] unless key.nil?
  end
  return value
end

def key_get_comment(keyname)
  comment = nil
  do_on_kdb_with_key keyname do |key|
    unless key.nil?
      key.meta.find_all do |e|
        e.name.start_with? COMMENT+"/#"
      end.each do |c|
        comment = "" if comment.nil?
        if c.value.start_with? "#"
          comment += c.value[1..-1]
        else
          comment += c.value
        end
      end
    end
  end
  return comment
end







describe Puppet::Type.type(:kdbkey).provider(:kdb) do

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
      ensure_key_is_missing keyname
      expect(provider.exists?).to eq(false)
    end

    it "should return true on exists? if key exists" do
      ensure_key_exists keyname
      expect(provider.exists?).to eq(true)
    end
  end

  context "should create key" do
    before :example do
      ensure_key_is_missing keyname
    end

    it "with defined name and no value" do
      provider.create
      expect(check_key_exists keyname).to eq(true)
      expect(key_get_value keyname).to eq("")
    end

    it "with defined name and value" do
      expect(check_key_exists keyname).to eq(false)
      provider.resource = create_resource(:name => keyname, 
                                          :value => "create with value")
      provider.create
      expect(check_key_exists keyname).to eq(true)
      expect(key_get_value keyname).to eq("create with value")
    end

    it "with defined name, value and metadata" do
      provider.resource[:value] = "my val"
      provider.resource[:metadata] = {"m1" => "v1", "m2" => "v2"}
      provider.create
      expect(check_key_exists keyname).to eq true
      expect(key_get_value keyname).to eq "my val"
      expect(check_meta_exists keyname, "m1").to eq true
      expect(key_get_meta keyname, "m1").to eq "v1"
      expect(check_meta_exists keyname, "m2").to eq true
      expect(key_get_meta keyname, "m2").to eq "v2"
    end
  end

  context "should update the key value" do
    before :example do
      ensure_key_exists keyname, "test"
    end

    it "to an arbitrary string" do
      provider.resource[:value] = "some string value"

      expect(key_get_value keyname).to eq("test")
      provider.value= "some string value"
      expect(key_get_value keyname).to eq("some string value")
    end

    it "to an empty string" do
      expect(key_get_value keyname).to eq("test")
      provider.value= ""
      expect(key_get_value keyname).to eq("")
    end
  end

  context "should remove key" do
    before :example do
      ensure_key_exists keyname
    end

    it "when key exists" do
      expect(check_key_exists keyname).to eq true
      provider.destroy
      expect(check_key_exists keyname).to eq false
    end
  end

  context "should get metadata values" do
    before :example do
      ensure_meta_exists keyname, "m1", "test"
      ensure_meta_exists keyname, "m2", "test"
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
      ensure_key_exists keyname
    end

    it "with missing metadata key" do
      ensure_meta_is_missing keyname, "m1"
      ensure_meta_is_missing keyname, "m2"
      provider.resource[:metadata] = metadata

      provider.metadata= metadata

      expect(check_meta_exists keyname, "m1").to eq true
      expect(check_meta_exists keyname, "m2").to eq true
      expect(key_get_meta keyname, "m1").to eq "v1"
      expect(key_get_meta keyname, "m2").to eq "v2"
    end

    it "with existing metadata" do
      ensure_meta_exists keyname, "m1", "test"
      ensure_meta_exists keyname, "m2", "test"
      provider.resource[:metadata] = metadata

      provider.metadata= metadata

      expect(check_meta_exists keyname, "m1").to eq true
      expect(check_meta_exists keyname, "m2").to eq true
      expect(key_get_meta keyname, "m1").to eq "v1"
      expect(key_get_meta keyname, "m2").to eq "v2"
    end
  end

  context "should purge not specified metadata if 'purge_meta_keys' is set" do
    let(:metadata) { {"m1" => "v1", "m2" => "v2"} }
    before :example do
      provider.resource[:purge_meta_keys] = true

      ensure_meta_is_missing keyname, "m1"
      ensure_meta_exists keyname, "m2"
      ensure_meta_exists keyname, "r1", "to remove"
      ensure_meta_exists keyname, "r2", "to remove"
    end

    it "while updating specified" do
      provider.metadata
      provider.metadata = metadata

      expect(check_meta_exists keyname, "m1").to eq true
      expect(check_meta_exists keyname, "m2").to eq true
      expect(key_get_meta keyname, "m1").to eq "v1"
      expect(key_get_meta keyname, "m2").to eq "v2"

      #expect(check_meta_exists keyname, "r1").to eq false
      #expect(check_meta_exists keyname, "r2").to eq false
      expect(key_get_meta keyname, "r1").to eq ""
      expect(key_get_meta keyname, "r2").to eq ""
    end

    # we can't test is this way, as we can not set 'internal' metadata
    # values
    #it "while ignoring meta keys starting with 'internal/'" do
    #  ensure_meta_exists keyname, "internal/puppet/test", "keep it"

    #  puts provider.metadata
    #  provider.metadata = metadata

    #  expect(check_meta_exists keyname, "m1").to eq true
    #  expect(check_meta_exists keyname, "m2").to eq true

    #  expect(check_meta_exists keyname, "internal/puppet/test").to eq true
    #  expect(key_get_meta keyname, "internal/puppet/test").to eq "keep it"

    #  #expect(check_meta_exists keyname, "r1").to eq false
    #  #expect(check_meta_exists keyname, "r2").to eq false
    #  expect(key_get_meta keyname, "r1").to eq ""
    #  expect(key_get_meta keyname, "r2").to eq ""
    #end

    it "while ignoring comments, which are not modified" do
      ensure_comment_exists keyname, " some comments"

      provider.metadata
      provider.metadata = metadata

      #expect(check_meta_exists keyname, COMMENT+"/#0").to eq true
      expect(check_comment_exists keyname).to eq true

      #expect(key_get_meta keyname, COMMENT+"/#0").to eq "# some comments"
      expect(key_get_comment keyname).to eq " some comments"
    end

    it "while ignoring commens which are added too" do
      provider.metadata = metadata
      provider.comments = "comment defined by me"

      provider.metadata
      provider.metadata = metadata

      expect(check_comment_exists keyname).to eq true
      #expect(check_meta_exists keyname, "r1").to eq false
      expect(key_get_meta keyname, "r1").to eq ""
    end

    it "while ignoring 'order' metadata" do
      ensure_meta_exists keyname, "order", "5"

      provider.metadata
      provider.metadata = metadata

      expect(check_meta_exists keyname, "order").to eq true
      expect(key_get_meta keyname, "order").to eq "5"
      #expect(check_meta_exists keyname, "r1").to eq false
      expect(key_get_meta keyname, "r1").to eq ""
    end

  end
end
