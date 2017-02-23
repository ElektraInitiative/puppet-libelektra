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

def ensure_key_exists(key, value = "test")
  do_on_kdb do |ks|
    key = ks.lookup("#{TEST_NS}x1")
    if key.nil?
      ks << Kdb::Key.new("#{TEST_NS}x1", value: value)
    else
      key.value = value
    end
  end
end

def ensure_key_is_missing(key)
  do_on_kdb do |ks|
    unless ks.lookup("#{TEST_NS}x1").nil?
      ks.delete "#{TEST_NS}x1"
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

def key_get_value(name)
  value = nil
  do_on_kdb do |ks|
    key = ks.lookup name
    value = key.value unless key.nil?
  end
  return value
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
end
