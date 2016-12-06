# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

require 'spec_helper'


describe Puppet::Type.type(:kdbmount) do

  context "property 'name'" do
    let(:name) { "user/test/puppet" }
    it "exists and is mandatory" do
      expect(described_class.new(:name => name)[:name]).to eq(name)
      expect { described_class.new() }.to raise_error(ArgumentError)
    end

    RSpec.shared_examples "valid key names" do |name|
      it "accepts the key name '#{name}'" do
        expect(described_class.new(:name => name)[:name]).to eq(name)
      end
    end

    context "accepts valid libelektra key names" do
      # cascading key name
      include_examples "valid key names", "/test/puppet"
      # absolute, by namespace key names
      include_examples "valid key names", "spec/test/puppet"
      #include_examples "valid key names", "proc/test/puppet"
      include_examples "valid key names", "dir/test/puppet"
      include_examples "valid key names", "user/test/puppet"
      include_examples "valid key names", "system/test/puppet"
    end

    RSpec.shared_examples "invalid key names" do |name|
      it "rejects the invalid key name '#{name}'" do
        expect { 
          described_class.new(:name => name) 
        }.to raise_error(Puppet::ResourceError)
      end
    end

    context "rejects invalid libelektra key names" do
      include_examples "invalid key names", ""
      include_examples "invalid key names", "hello/world"
      include_examples "invalid key names", "invalid-name-space"
      include_examples "invalid key names", "test/xy"
    end
  end

  context "property 'file'" do
    let(:params) { {
      :name => "user/test/puppet",
      :file => "some value"} 
    }
    it "exists" do
      expect(described_class.new(params)[:file]).to eq(params[:file])
    end

    let(:params) { {
      :name => "user/test/puppet"}
    }
    it "is optional" do
      expect(described_class.new(params)[:file]).to be_nil
    end
  end


  context "property 'plugins'" do
    let(:params) { {
      :name    => "user/test/puppet",
      :plugins => { 'plugin1' => 'sync' }
      }
    }
    it "exists" do
      expect(described_class.new(params)[:plugins]).to eq(["sync"])
    end

    let(:params) { {
      :name => "user/test/puppet"
      }
    }
    it "is optional" do
      expect(described_class.new(params)[:plugins]).to be_nil
    end
    #it "only accepts hash values" do
    #  p1 = params

    #  p1[:metadata] = ""
    #  expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

    #  p1[:metadata] = "not a hash"
    #  expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

    #  p1[:metadata] = 1
    #  expect { described_class.new(p1) }.to raise_error(Puppet::ResourceError)

    #  p1[:metadata] = {
    #    'meta1' => 'value 1',
    #    'meta2' => 'value 2'
    #  }
    #  expect(described_class.new(p1)[:metadata]).to eq(p1[:metadata])
    #end
  end

end
