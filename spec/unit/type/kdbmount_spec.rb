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
      :name    => "user/test/puppet"
      }
    }
    it "exists and is optional if file is not used" do
      expect(described_class.new(params)[:plugins]).to be_nil
    end

    it "exists and is mandatory if file is set" do
      params[:file] = 'somefile.txt'
      expect { described_class.new(params) }.to raise_error(Puppet::Error)
    end

    it "accepts a string" do
      params[:file] = 'somefile.ini'
      params[:plugins] = "ini"
      expect(described_class.new(params)[:plugins]).to eq ["ini"]
    end

    it "accepts an array of strings" do
      params[:file] = 'somefile.ini'
      params[:plugins] = ["ini", "type"]
      expect(described_class.new(params)[:plugins]).to eq ["ini", "type"]
    end

    it "accepts an array with plugin name with corresponding configuration settings" do
      params[:file] = 'somefile.ini'
      params[:plugins] = ["ini", {"seperator" => " ", "array" => ""}]
      expect(described_class.new(params)[:plugins]).to eq params[:plugins]
    end

    it "accepts a Hash with plugin name with corresponding configuration settings" do
      params[:file] = 'somefile.ini'
      params[:plugins] = {"ini" => {"seperator" => " ", "array" => ""}}
      # we always get an Array back
      expect(described_class.new(params)[:plugins]).to eq [params[:plugins]]
    end

    RSpec.shared_examples "invalid plugin names" do |plugins|
      it "rejects invalid plugin names '#{plugins}'" do
        expect { 
          described_class.new(:name => params[:name], :plugins => plugins)
        }.to raise_error(Puppet::ResourceError)
      end
    end

    context "rejects invalid plugin names" do
      include_examples "invalid plugin names", "invalid plugin"
      include_examples "invalid plugin names", " ini"
      include_examples "invalid plugin names", [" ini"]
      include_examples "invalid plugin names", ["ini", "type "]
      include_examples "invalid plugin names", ["ini", "type", "$doesnotexist%"]
    end
  end

end
