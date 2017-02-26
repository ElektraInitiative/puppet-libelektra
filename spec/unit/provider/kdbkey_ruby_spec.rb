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
  let(:ks) { Kdb::KeySet.new }
  let(:provider) { described_class.new }

  before :example do
    described_class.use_fake_ks ks
    provider.resource = create_resource :name => keyname
  end


  it "should be a child of Puppet::Provider" do
    expect(described_class.new).to be_a_kind_of(Puppet::Provider)
  end

  context "should check if resource exists" do
    it "should return false on exists? if resource does not exist'" do
      expect(provider.exists?).to eq(false)
    end

    it "should return true on exists? if resource exists'" do
      h.ensure_key_exists ks, keyname
      expect(provider.exists?).to eq(true)
    end

  end

  context "should create key" do
    before :example do
      h.ensure_key_is_missing ks, keyname
    end

    it "with defined name" do
      provider.create
      expect(h.check_key_exists ks, keyname).to eq true
    end

    it "with defined name and value" do
      value = "my value"
      provider.resource = create_resource :name => keyname, :value => value

      provider.create

      expect(h.check_key_exists ks, keyname).to eq true
      expect(h.key_get_value ks, keyname).to eq value
    end

    it "with defined name, value and metadata" do
      value = "my value"
      meta = {'meta1' => 'v1', 'meta2' => 'v2' }
      provider.resource = create_resource :name     => keyname,
                                          :value    => value,
                                          :metadata => meta

      provider.create

      expect(h.check_key_exists ks, keyname).to eq true
      expect(h.key_get_value ks, keyname).to eq value
      meta.each do |k, v|
        expect(h.key_get_meta ks, keyname, k).to eq v
      end
    end

    it "with defined name, value, metadata and comments" do
      value = "my value"
      meta = {'meta1' => 'v1', 'meta2' => 'v2' }
      comments = "my comment"

      provider.resource = create_resource :name     => keyname,
                                          :value    => value,
                                          :metadata => meta,
                                          :comments => comments

      provider.create

      expect(h.check_key_exists ks, keyname).to eq true
      expect(h.key_get_value ks, keyname).to eq value
      meta.each do |k, v|
        expect(h.key_get_meta ks, keyname, k).to eq(v)
      end
      expect(h.key_get_comment ks, keyname).to eq comments
    end


  end

  it "should remove key on destroy" do
    h.ensure_key_exists ks, keyname
    # we have to call exists? first
    provider.exists?
    provider.destroy

    expect(h.check_key_exists ks, keyname).to eq false
  end

  context "with existing key" do
    before :example do
      h.ensure_key_exists ks, keyname, "test"
      provider.exists?
    end

    context "should update the key value" do
      it "to an arbitrary string" do
        expect(h.key_get_value ks, keyname).to eq "test"
        provider.value= "some string value"
        expect(h.key_get_value ks, keyname).to eq "some string value"
      end

      it "to an empty string" do
        expect(h.key_get_value ks, keyname).to eq "test"
        provider.value= ""
        expect(h.key_get_value ks, keyname).to eq ""
      end
    end

    context "and existing metadata" do
      let(:metadata) { {"m1" => "v1", "m2" => "v2"} }
      before :example do
        h.ensure_meta_exists ks, keyname, "m1", metadata["m1"]
        h.ensure_meta_exists ks, keyname, "m2", metadata["m2"]
        provider.resource[:metadata]= metadata
      end

      context "should get metadata values" do
        it "as a hash" do
          got_meta = provider.metadata

          expect(got_meta).to be_a_kind_of Hash
          expect(got_meta["m1"]).to eq "v1"
          expect(got_meta["m2"]).to eq "v2"
        end

        # otherwise, Puppet will think we have to update something and
        # triggers an update for metadata.
        it "but not include unspecified keys if 'purge_meta_keys' is not set" do
          h.ensure_meta_exists ks, keyname, "m3", "xxx"

          got_meta = provider.metadata

          expect(got_meta.include? "m1").to eq true
          expect(got_meta.include? "m2").to eq true
          expect(got_meta.include? "m3").to eq false
        end

        it "and ignore 'internal' metakeys" do
          h.ensure_meta_exists ks, keyname, "internal/ini/order", "5"
          h.ensure_meta_exists ks, keyname, "internal/ini/parent", "xxx"

          got_meta = provider.metadata

          expect(got_meta.include? "internal/ini/order").to eq false
          expect(got_meta.include? "internal/ini/parent").to eq false
        end

        it "and ignore 'internal' metakeys with 'purge_meta_keys' set" do
          h.ensure_meta_exists ks, keyname, "internal/ini/order", "5"
          h.ensure_meta_exists ks, keyname, "internal/ini/parent", "xxx"
          h.ensure_meta_exists ks, keyname, "comment/#0", "xxx"
          h.ensure_meta_exists ks, keyname, "comments/#0", "xxx"
          h.ensure_meta_exists ks, keyname, "comments", "#1"
          h.ensure_meta_exists ks, keyname, "order", "5"

          provider.resource[:purge_meta_keys] = true
          got_meta = provider.metadata

          expect(got_meta.include? "internal/ini/order").to eq false
          expect(got_meta.include? "internal/ini/parent").to eq false
          expect(got_meta.include? "comment/#0").to eq false
          expect(got_meta.include? "comments/#0").to eq false
          expect(got_meta.include? "comments").to eq false
          expect(got_meta.include? "order").to eq false
        end

        it "and ignore 'special' metakeys with 'purge_meta_key' unless specified" do
          h.ensure_meta_exists ks, keyname, "comments/#0", "xxx"
          h.ensure_meta_exists ks, keyname, "comments", "#1"

          metadata["comments/#0"] = "xxx"
          metadata["comments"] = "#1"
          provider.resource[:metadata] = metadata
          provider.resource[:purge_meta_keys] = true

          got_meta = provider.metadata

          expect(got_meta.include? "comments/#0").to eq true
          expect(got_meta.include? "comments").to eq true
        end
      end

      context "should update the metadata" do
        it "with missing metadata key" do
          metadata["m3"] = "v3"
          provider.resource[:metadata]= metadata
          provider.metadata= metadata

          got_meta = provider.metadata

          expect(got_meta.include? "m3").to eq true
          expect(got_meta["m3"]).to eq "v3"
        end

        it "with existing metadata" do
          got_meta = provider.metadata

          expect(got_meta.include? "m1").to eq true
          expect(got_meta.include? "m2").to eq true
          expect(got_meta["m1"]).to eq "v1"
          expect(got_meta["m2"]).to eq "v2"
        end
      end

      context "should purge not specified metadata if 'purge_meta_keys' is set" do
        before :example do
          h.ensure_meta_exists ks, keyname, "r1", "to remove"
          h.ensure_meta_exists ks, keyname, "r2", "to remove"
          provider.resource[:purge_meta_keys] = true
        end

        def has_expected_but_not_specified(got_meta)
          expect(got_meta.include? "m1").to eq true
          expect(got_meta.include? "m2").to eq true
          expect(got_meta.include? "r1").to eq false
          expect(got_meta.include? "r2").to eq false

          expect(got_meta["m1"]).to eq "v1"
          expect(got_meta["m2"]).to eq "v2"
        end

        it "while updating specified" do
          h.ensure_meta_exists ks, keyname, "m1", "old value"
          provider.metadata= metadata

          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
        end

        it "while ignoring comments, which are not modified" do
          h.ensure_comment_exists ks, keyname, "some comment"

          provider.metadata= metadata
          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists ks, keyname).to eq true
          expect(h.key_get_comment ks, keyname).to eq "some comment"
        end

        it "while ignoring comments, which are added too (before)" do
          provider.comments= "some comment"
          provider.metadata= metadata

          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists ks, keyname).to eq true
          expect(h.key_get_comment ks, keyname).to eq "some comment"
        end

        it "while ignoring comments, which are added too (after)" do
          provider.metadata= metadata
          provider.comments= "some comment"

          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists ks, keyname).to eq true
          expect(h.key_get_comment ks, keyname).to eq "some comment"
        end

        it "while ignoring 'internal/' metadata keys" do
          h.ensure_meta_exists ks, keyname, "internal/test1", "to keep"

          provider.metadata= metadata
          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_meta_exists ks, keyname, "internal/test1").to eq true
          expect(h.key_get_meta ks, keyname, "internal/test1").to eq "to keep"
        end

        it "while ignoring 'order' metadata" do
          h.ensure_meta_exists ks, keyname, "order", "5"

          provider.metadata= metadata
          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_meta_exists ks, keyname, "order").to eq true
          expect(h.key_get_meta ks, keyname, "order").to eq "5"
        end
      end
    end

    context "should handle comments" do
      it "and fetch the comment string" do
        h.ensure_comment_exists ks, keyname, "my comment"

        expect(provider.comments).to eq "my comment"
      end

      it "and fetch a multiline comment string at once" do
        expected_comment = <<EOT
this  
is
a
multiline
comment
EOT
        expected_comment.chomp!

        h.ensure_comment_exists ks, keyname, expected_comment

        expect(provider.comments).to eq expected_comment
      end

      it "and create a new comment" do
        provider.comments= " my comment line  "
        expect(h.check_comment_exists ks, keyname).to eq true
        expect(h.key_get_comment ks, keyname).to eq " my comment line  "
      end

      it "and update a multi line comment" do
        expected_comment = <<EOT
yet another
mulitline
comment
EOT
        expected_comment.chomp!

        h.ensure_comment_exists ks, keyname, "a single line comment"

        provider.comments= expected_comment

        expect(h.key_get_comment ks, keyname).to eq expected_comment
      end

      it "and update from a multi line comment to a single line comment" do
        h.ensure_comment_exists ks, keyname, <<EOT
a
simple
multiline

comment
EOT

        provider.comments= "a single line comment "

        expect(h.key_get_comment ks, keyname).to eq "a single line comment "
      end
    end
  end

end
