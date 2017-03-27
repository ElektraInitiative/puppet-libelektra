# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

require 'spec_helper'


describe Puppet::Type.type(:kdbkey) do

  context "property 'name'" do
    let(:name) { "user/test/puppet/x1" }
    it "exists and is mandatory" do
      expect(described_class.new(:name => name)[:name]).to eq(name)
      expect { described_class.new() }.to raise_error(ArgumentError)
    end

    RSpec.shared_examples "kdbkey valid key names" do |name|
      it "accepts the key name '#{name}'" do
        expect(described_class.new(:name => name)[:name]).to eq(name)
      end
    end

    context "accepts valid libelektra key names" do
      # cascading key name
      include_examples "kdbkey valid key names", "/test/puppet"
      # absolute, by namespace key names
      include_examples "kdbkey valid key names", "spec/test/puppet"
      include_examples "kdbkey valid key names", "proc/test/puppet"
      include_examples "kdbkey valid key names", "dir/test/puppet"
      include_examples "kdbkey valid key names", "user/test/puppet"
      include_examples "kdbkey valid key names", "system/test/puppet"
    end

    RSpec.shared_examples "kdbkey invalid key names" do |name|
      it "rejects the invalid key name '#{name}'" do
        expect {
          described_class.new(:name => name)
        }.to raise_error(Puppet::ResourceError)
      end
    end

    context "rejects invalid libelektra key names" do
      include_examples "kdbkey invalid key names", ""
      include_examples "kdbkey invalid key names", "hello/world"
      include_examples "kdbkey invalid key names", "invalid-name-space"
      include_examples "kdbkey invalid key names", "test/xy"
    end
  end

  context "property 'prefix'" do
    let(:name) { "/test/puppet/x1" }
    let(:prefix) { "user" }
    it "exists and is optional with default value ''" do
      expect(described_class.new(:name => name,
                                 :prefix => prefix)[:prefix]
            ).to eq(prefix)
      expect(described_class.new(:name => name)[:prefix]).to eq("")
    end

    RSpec.shared_examples "kdbkey valid key prefix" do |prefix|
      it "accepts the key prefix '#{prefix}'" do
        expect(described_class.new(:name => "/test",
                                   :prefix => prefix)[:prefix]
              ).to eq(prefix)
      end
    end

    context "accepts valid libelektra key name prefix" do
      # cascading key name
      include_examples "kdbkey valid key prefix", "/test/puppet"
      # absolute, by namespace key names
      include_examples "kdbkey valid key prefix", "spec/test/puppet"
      include_examples "kdbkey valid key prefix", "proc/test/puppet"
      include_examples "kdbkey valid key prefix", "dir/test/puppet"
      include_examples "kdbkey valid key prefix", "user/test/puppet"
      include_examples "kdbkey valid key prefix", "system/test/puppet"
      # without trailing /
      include_examples "kdbkey valid key prefix", "system"
    end

    RSpec.shared_examples "kdbkey invalid key prefix" do |prefix|
      it "rejects the invalid key prefix '#{prefix}'" do
        expect {
          described_class.new(:name    => "/test",
                              :prefix => prefix)
        }.to raise_error(Puppet::ResourceError)
      end
    end

    context "rejects invalid libelektra key names" do
      include_examples "kdbkey invalid key prefix", "hello/world"
      include_examples "kdbkey invalid key prefix", "invalid-name-space"
      include_examples "kdbkey invalid key prefix", "test/xy"
    end

    RSpec.shared_examples "prefix + name" do |prefix, name, expected|
      it "with '#{prefix}' (name: '#{name}')" do
        expect(described_class.new(:name => name, :prefix => prefix)[:name]).to eq(expected)
      end
    end

    context "prefixes name property" do
      include_examples "prefix + name", "user", "/test/puppet/x1", "user/test/puppet/x1"
      include_examples "prefix + name", "system", "/test/puppet/x1", "system/test/puppet/x1"
      include_examples "prefix + name", "system/test", "/puppet/x1", "system/test/puppet/x1"
      include_examples "prefix + name", "system/", "/test/puppet/x1", "system/test/puppet/x1"
      include_examples "prefix + name", "system/", "test/puppet/x1", "system/test/puppet/x1"
      include_examples "prefix + name", "system", "test/puppet/x1", "system/test/puppet/x1"
    end

    it "updates 'title' to match new 'name'" do
      expect(described_class.new(:prefix => "user/test",
                                 :name   => "/puppet/x1").title
            ).to eq("user/test/puppet/x1")
    end
  end

  context "property 'value'" do
    let(:params) { {:name => "user/test/puppet/x1", :value => "some value"} }
    let(:params_wo_value) { {:name => "user/test/puppet/x1"} }
    let(:params_w_array) { {:name => "user/test/puppet/x1", :value => ['one', 'two']} }
    it "exists and is optional" do
      expect(described_class.new(params_wo_value)[:value]).to be_nil
    end
    it "returns an array of values" do
      expect(described_class.new(params)[:value]).to eq([params[:value]])
      expect(described_class.new(params_w_array)[:value]).to eq(params_w_array[:value])
    end

  end


  context "property 'metadata'" do
    let(:params) { {:name => "user/test/puppet/x1", :value => ""} }
    it "exists and is optional" do
      expect(described_class.new(params)[:metadata]).to be_nil
    end

    it "only accepts hash values" do
      p1 = params

      p1[:metadata] = ""
      expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

      p1[:metadata] = "not a hash"
      expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

      p1[:metadata] = 1
      expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

      p1[:metadata] = {
        'meta1' => 'value 1',
        'meta2' => 'value 2'
      }
      expect(described_class.new(p1)[:metadata]).to eq(p1[:metadata])
    end
  end


  context "parameter 'purge_meta_keys'" do
    let(:params) { {:name => "user/test/puppet/x1"} }
    it "exists and is default false" do
      expect(described_class.new(params)[:purge_meta_keys]).to be_falsy
    end

    it "only accepts boolean values" do
      p = params

      p[:purge_meta_keys] = "this is not a truth value"
      expect { described_class.new(p) }.to raise_error(Puppet::ResourceError)

      p[:purge_meta_keys] = "true"
      expect(described_class.new(p)[:purge_meta_keys]).to be true

      p[:purge_meta_keys] = true
      expect(described_class.new(p)[:purge_meta_keys]).to be true

      p[:purge_meta_keys] = "false"
      expect(described_class.new(p)[:purge_meta_keys]).to be false
    end
  end


  context "parameter 'comments'" do
    let(:params) { {:name => "user/test/puppet/x1"} }
    it "exists and is optional" do
      expect(described_class.new(params)[:comments]).to be_nil
    end
  end

  context "property 'check'" do
    let(:params) { {:name => "user/test/puppet/x1"} }
    it "exists and is optional" do
      expect(described_class.new(params)[:check]).to be_nil
    end

    it "accepts a Hash" do
      params[:check] = {"type" => "short"}
      expect(described_class.new(params)[:check]).to eq params[:check]
    end

    it "accepts a String" do
      params[:check] = "path"
      expect(described_class.new(params)[:check]).to eq params[:check]
    end

    it "rejects values for a key within the 'spec' namespace" do
      params[:name] = "spec/test/puppet/x1"
      params[:check] = "path"
      expect {
        described_class.new(params)
      }.to raise_error(Puppet::Error)
    end

    it "rejects values for a key within the 'spec' namespace "\
       "and prefix is used" do
      params[:prefix] = "spec/test"
      params[:name] = "puppet/x1"
      params[:check] = "path"
      expect {
        described_class.new(params)
      }.to raise_error(Puppet::Error)
    end
  end

  context "parameter 'user'" do
    let(:params) { {:name => "user/test/puppet/x1"} }
    it "exists and is optional" do
      expect(described_class.new(params)[:user]).to be_nil
    end
  end

  context "auto requires kdbmounts" do

    RSpec.shared_examples "autorequire kdbmounts" do |keyname, expected|
      it "each possible mountpoint for '#{keyname}'" do
        t = described_class.new({:name => keyname})
        autoreq = {}
        t.class.eachautorequire do |type,block|
          autoreq[type] = t.instance_eval(&block)
        end

        expect(autoreq.include? :kdbmount).to be true
        expect(autoreq.include? :kdbkey).to be true

        expect(autoreq[:kdbmount]).to eq expected

        # kdbkey should not require itself
        expected.delete keyname
        expect(autoreq[:kdbkey]).to eq expected
      end
    end

    include_examples "autorequire kdbmounts", "user/test", ["user", "user/test"]
    include_examples "autorequire kdbmounts",
      "system/test",
      ["system", "system/test"]

    include_examples "autorequire kdbmounts",
      "system/test/hello/world",
      ["system", "system/test", "system/test/hello", "system/test/hello/world"]

    include_examples "autorequire kdbmounts",
      'system/test/hello\/escaped\/world/a/b',
      ["system", "system/test", 'system/test/hello\/escaped\/world',
       'system/test/hello\/escaped\/world/a',
       'system/test/hello\/escaped\/world/a/b']

    include_examples "autorequire kdbmounts", "/test/puppet", [
      "system/test", "system/test/puppet",
      "user/test", "user/test/puppet",
      "spec/test", "spec/test/puppet",
      "dir/test", "dir/test/puppet"
    ]

  end


end
