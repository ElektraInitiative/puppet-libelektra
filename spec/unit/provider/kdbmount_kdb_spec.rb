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



describe Puppet::Type.type(:kdbkey).provider(:ruby) do

  let(:name)     { "#{TEST_NS}x1" }
  let(:ks)       { double("ks") }
  let(:provider) { described_class.new }

  before :example do
    described_class.use_fake_ks ks
    provider.resource = create_resource :name => name
  end


  it "should be a child of Puppet::Provider" do
    expect(described_class.new).to be_a_kind_of(Puppet::Provider)
  end

  context "should check if resource exists" do
    it "should return false on exists? if resource does not exist'" do
      allow(ks).to receive(:lookup).and_return nil

      expect(ks).to receive(:lookup) { name }
      # for some very strange reason the first call inside expect(..) is true
      provider.exists?
      expect(provider.exists?).to eq(false)
      expect(provider.resource_key).to be_nil
    end

    it "should return true on exists? if resource exists'" do
      key = Kdb::Key.new name
      allow(ks).to receive(:lookup).and_return key

      expect(ks).to receive(:lookup) { name }
      provider.exists?
      expect(provider.exists?).to eq(true)
      expect(provider.resource_key).to be(key)
    end

  end

  context "should create key" do
    before :example do
      allow(ks).to receive(:<<)
      expect(ks).to receive(:<<) { provider.resource_key }
    end

    it "with defined name" do
      provider.create
      key = provider.resource_key

      expect(key.name).to eq(name)
    end

    it "with defined name and value" do
      value = "my value"
      provider.resource = create_resource :name => name, :value => value

      provider.create

      expect(provider.resource_key.name).to eq(name)
      expect(provider.resource_key.value).to eq(value)
    end

    it "with defined name, value and metadata" do
      value = "my value"
      meta = {'meta1' => 'v1', 'meta2' => 'v2' }
      provider.resource = create_resource :name     => name, 
                                          :value    => value,
                                          :metadata => meta

      provider.create

      expect(provider.resource_key.name).to eq(name)
      expect(provider.resource_key.value).to eq(value)
      meta.each do |k, v|
        expect(provider.resource_key.get_meta k).to eq(v)
      end
    end

    it "with defined name, value, metadata and comments" do
      value = "my value"
      meta = {'meta1' => 'v1', 'meta2' => 'v2' }
      comments = "my comment"

      provider.resource = create_resource :name     => name, 
                                          :value    => value,
                                          :metadata => meta,
                                          :comments => comments

      provider.create

      expect(provider.resource_key.name).to eq(name)
      expect(provider.resource_key.value).to eq(value)
      meta.each do |k, v|
        expect(provider.resource_key.get_meta k).to eq(v)
      end
      expect(provider.resource_key['comments']).to eq("#0")
      expect(provider.resource_key['comments/#0']).to eq("# #{comments}")
    end


  end

  it "should do nothing on destroy when resource_key is nil" do
    provider.destroy
  end

  it "should remove key when we have a key" do
    # first create the key, a delete on nil-key does not make sense
    allow(ks).to receive(:<<)
    provider.create

    expect(ks).to receive(:delete) { nil }
    provider.destroy
  end

  it "should update the value"
  it "should update the metadata"
  it "should update the comments"
end
