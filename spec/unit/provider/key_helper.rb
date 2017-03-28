# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

# currently metadaa key for comments used by ini
# but hosts uses 'comment'
COMMENT = 'comments'


def create_resource(params)
  Puppet::Type.type(:kdbkey).new(params)
end

# since both provider should do the same thing we can use the
# same spec/tests for both of them
#
# but not each test case is possible for the :kdb provider,
# thus use not_testable_with_kdb = true when executed with :kdb
#
RSpec.shared_examples "a kdbkey provider" do |not_testable_with_kdb|

  it "should be a child of Puppet::Provider" do
    expect(described_class.new).to be_a_kind_of(Puppet::Provider)
  end

  context "should check if resource exists" do
    it "should return false on exists? if resource does not exist'" do
      h.ensure_key_is_missing keyname
      expect(provider.exists?).to eq(false)
    end

    it "should return true on exists? if resource exists'" do
      h.ensure_key_exists keyname
      expect(provider.exists?).to eq(true)
    end

  end

  context "should create key" do
    before :example do
      h.ensure_key_is_missing keyname
      h.ensure_key_is_missing provider.get_spec_key_name
    end

    it "with defined name" do
      provider.create
      provider.flush
      expect(h.check_key_exists keyname).to eq true
    end

    it "with defined name and value" do
      value = "my value"
      provider.resource = create_resource :name => keyname, :value => value

      provider.create
      provider.flush

      expect(h.check_key_exists keyname).to eq true
      expect(h.key_get_value keyname).to eq value
    end

    it "with defined name, value and metadata" do
      value = "my value"
      meta = {'meta1' => 'v1', 'meta2' => 'v2' }
      provider.resource = create_resource :name     => keyname,
                                          :value    => value,
                                          :metadata => meta

      provider.create
      provider.flush

      expect(h.check_key_exists keyname).to eq true
      expect(h.key_get_value keyname).to eq value
      meta.each do |k, v|
        expect(h.key_get_meta keyname, k).to eq v
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
      provider.flush

      expect(h.check_key_exists keyname).to eq true
      expect(h.key_get_value keyname).to eq value
      meta.each do |k, v|
        expect(h.key_get_meta keyname, k).to eq(v)
      end
      expect(h.key_get_comment keyname).to eq comments
    end

    it "with defined name, value, meta, comments and spec" do
      value = "5"
      meta = {"nvmcs" => "some value"}
      comments = "other comments"
      checks = {'type' => 'short'}

      provider.resource = create_resource :name => keyname,
                                          :value => value,
                                          :metadata => meta,
                                          :comments => comments,
                                          :check => checks

      provider.create
      provider.flush

      expect(h.check_key_exists keyname).to eq true
      expect(h.key_get_value keyname).to eq value
      meta.each do |k, v|
        expect(h.key_get_meta keyname, k).to eq(v)
      end
      expect(h.key_get_comment keyname).to eq comments
      expect(h.check_key_exists provider.get_spec_key_name).to eq true
      expect(
        h.key_get_meta provider.get_spec_key_name, 'check/type'
      ).to eq 'short'
    end


  end

  context "should remove key on destroy" do
    it "for single value keys" do
      h.ensure_key_exists keyname
      # we have to call exists? first
      provider.exists?
      provider.destroy
      provider.flush

      expect(h.check_key_exists keyname).to eq false
    end

    it "for array value keys" do
      h.ensure_key_exists keyname, ''
      h.ensure_key_exists "#{keyname}/#0" 'one'
      h.ensure_key_exists "#{keyname}/#1" 'one'

      provider.exists?
      provider.destroy
      provider.flush

      expect(h.check_key_exists keyname).to eq false
      expect(h.check_key_exists "#{keyname}/#0").to eq false
      expect(h.check_key_exists "#{keyname}/#1").to eq false
    end
  end

  context "with existing key" do
    before :example do
      h.ensure_key_exists keyname, "test"
      provider.exists?
    end

    context "should read the key's value" do
      it "for a single string value" do
        expect(provider.value).to eq ["test"]
      end

      it "for an Array of strings" do
        h.ensure_key_exists keyname, ''
        h.ensure_key_exists "#{keyname}/#0", 'one'
        h.ensure_key_exists "#{keyname}/#1", 'two'
        h.ensure_key_exists "#{keyname}/#2", 'three'

        expect(provider.value).to eq ['one', 'two', 'three']
      end
    end

    context "should update the key value" do
      it "to an arbitrary string" do
        expect(h.key_get_value keyname).to eq "test"
        provider.value= ["some string value"]
        provider.flush
        expect(h.key_get_value keyname).to eq "some string value"
      end

      it "to an empty string" do
        expect(h.key_get_value keyname).to eq "test"
        provider.value= [""]
        provider.flush
        expect(h.key_get_value keyname).to eq ""
      end

      it "to an truth value" do
        provider.value= [true]
        provider.flush
        expect(h.key_get_value keyname).to eq "true"
      end

      it "to a numerical value" do
        provider.value= [5]
        provider.flush
        expect(h.key_get_value keyname).to eq "5"
      end

      it "to an array of strings" do
        expect(h.key_get_value keyname).to eq "test"
        provider.value= ['one', 'two']
        provider.flush
        expect(h.key_get_value keyname).to eq ''
        expect(h.key_get_value "#{keyname}/#0").to eq 'one'
        expect(h.key_get_value "#{keyname}/#1").to eq 'two'
      end

      it "to an array of different types" do
        provider.value= ["string", 3, true, 5.5]
        provider.flush
        expect(h.key_get_value keyname).to eq ''
        expect(h.key_get_value "#{keyname}/#0").to eq 'string'
        expect(h.key_get_value "#{keyname}/#1").to eq '3'
        expect(h.key_get_value "#{keyname}/#2").to eq 'true'
        expect(h.key_get_value "#{keyname}/#3").to eq '5.5'
      end

      it "to an array while removing old array values" do
        h.ensure_key_exists keyname, ''
        h.ensure_key_exists "#{keyname}/#0", '1'
        h.ensure_key_exists "#{keyname}/#1", '2'
        h.ensure_key_exists "#{keyname}/#2", '3'
        h.ensure_key_exists "#{keyname}/#3", '4'
        h.ensure_key_exists "#{keyname}/#4", '5'

        provider.value= ['one', 'two']
        provider.flush

        expect(h.key_get_value keyname).to eq ''
        expect(h.key_get_value "#{keyname}/#0").to eq 'one'
        expect(h.key_get_value "#{keyname}/#1").to eq 'two'
        expect(h.check_key_exists "#{keyname}/#2").to eq false
        expect(h.check_key_exists "#{keyname}/#3").to eq false
        expect(h.check_key_exists "#{keyname}/#4").to eq false
      end

      it "to an string value while removing old array values" do
        h.ensure_key_exists keyname, ''
        h.ensure_key_exists "#{keyname}/#0", '1'
        h.ensure_key_exists "#{keyname}/#1", '2'
        h.ensure_key_exists "#{keyname}/#2", '3'
        h.ensure_key_exists "#{keyname}/#3", '4'
        h.ensure_key_exists "#{keyname}/#4", '5'

        provider.value= "my new string value"
        provider.flush

        expect(h.key_get_value keyname).to eq "my new string value"
        expect(h.check_key_exists "#{keyname}/#0").to eq false
        expect(h.check_key_exists "#{keyname}/#1").to eq false
        expect(h.check_key_exists "#{keyname}/#2").to eq false
        expect(h.check_key_exists "#{keyname}/#3").to eq false
        expect(h.check_key_exists "#{keyname}/#4").to eq false
      end
    end

    context "and existing metadata" do
      let(:metadata) { {"m1" => "v1", "m2" => "v2"} }
      before :example do
        h.ensure_meta_exists keyname, "m1", metadata["m1"]
        h.ensure_meta_exists keyname, "m2", metadata["m2"]
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
          h.ensure_meta_exists keyname, "m3", "xxx"

          got_meta = provider.metadata

          expect(got_meta.include? "m1").to eq true
          expect(got_meta.include? "m2").to eq true
          expect(got_meta.include? "m3").to eq false
        end

        it "and ignore 'internal' metakeys" do
          h.ensure_meta_exists keyname, "internal/ini/order", "5"
          h.ensure_meta_exists keyname, "internal/ini/parent", "xxx"

          got_meta = provider.metadata

          expect(got_meta.include? "internal/ini/order").to eq false
          expect(got_meta.include? "internal/ini/parent").to eq false
        end

        it "and ignore 'internal' metakeys with 'purge_meta_keys' set" do
          h.ensure_meta_exists keyname, "internal/ini/order", "5"
          h.ensure_meta_exists keyname, "internal/ini/parent", "xxx"
          h.ensure_meta_exists keyname, "comment/#0", "xxx"
          h.ensure_meta_exists keyname, "comments/#0", "xxx"
          h.ensure_meta_exists keyname, "comments", "#1"
          h.ensure_meta_exists keyname, "order", "5"

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
          h.ensure_meta_exists keyname, "comments/#0", "xxx"
          h.ensure_meta_exists keyname, "comments", "#1"

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
          provider.flush

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
          h.ensure_meta_exists keyname, "r1", "to remove"
          h.ensure_meta_exists keyname, "r2", "to remove"
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
          h.ensure_meta_exists keyname, "m1", "old value"
          provider.metadata= metadata
          provider.flush

          got_meta = provider.metadata

          expect(h.check_meta_exists keyname, "m1").to eq true
          expect(h.check_meta_exists keyname, "m2").to eq true
          expect(h.check_meta_exists keyname, "r1").to eq false
          expect(h.check_meta_exists keyname, "r2").to eq false
          has_expected_but_not_specified got_meta
        end

        it "while ignoring comments, which are not modified" do
          h.ensure_comment_exists keyname, "some comment"

          provider.metadata= metadata
          provider.flush
          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists keyname).to eq true
          expect(h.key_get_comment keyname).to eq "some comment"
        end

        it "while ignoring comments, which are added too (before)" do
          provider.comments= "some comment"
          provider.metadata= metadata
          provider.flush

          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists keyname).to eq true
          expect(h.key_get_comment keyname).to eq "some comment"
        end

        it "while ignoring comments, which are added too (after)" do
          provider.metadata= metadata
          provider.comments= "some comment"
          provider.flush

          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_comment_exists keyname).to eq true
          expect(h.key_get_comment keyname).to eq "some comment"
        end

        unless not_testable_with_kdb
          it "while ignoring 'internal/' metadata keys" do
            h.ensure_meta_exists keyname, "internal/test1", "to keep"

            provider.metadata= metadata
            provider.flush
            got_meta = provider.metadata

            has_expected_but_not_specified got_meta
            expect(h.check_meta_exists keyname, "internal/test1").to eq true
            expect(h.key_get_meta keyname, "internal/test1").to eq "to keep"
          end
        end

        it "while ignoring 'order' metadata" do
          h.ensure_meta_exists keyname, "order", "5"

          provider.metadata= metadata
          provider.flush
          got_meta = provider.metadata

          has_expected_but_not_specified got_meta
          expect(h.check_meta_exists keyname, "order").to eq true
          expect(h.key_get_meta keyname, "order").to eq "5"
        end
      end
    end

    context "should handle comments" do
      it "and fetch the comment string" do
        h.ensure_comment_exists keyname, "my comment"

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

        h.ensure_comment_exists keyname, expected_comment

        expect(provider.comments).to eq expected_comment
      end

      it "and create a new comment" do
        provider.comments= "my comment line"
        provider.flush
        expect(h.check_comment_exists keyname).to eq true
        expect(h.key_get_comment keyname).to eq "my comment line"
      end

      it "and update a multi line comment" do
        expected_comment = <<EOT
yet another
mulitline
comment
EOT
        expected_comment.chomp!

        h.ensure_comment_exists keyname, "a single line comment"

        provider.comments= expected_comment
        provider.flush

        expect(h.key_get_comment keyname).to eq expected_comment
      end

      it "and update from a multi line comment to a single line comment" do
        h.ensure_comment_exists keyname, <<EOT
a
simple
multiline

comment
EOT

        provider.comments= "a single line comment"
        provider.flush

        expect(h.key_get_comment keyname).to eq "a single line comment"
      end
    end
  end

  context "handle key specifications ('check')" do
    before :example do
      h.ensure_key_is_missing provider.get_spec_key_name
      h.ensure_key_exists keyname
      provider.exists?
    end

    it "get spec for a single String check" do
      h.ensure_meta_exists provider.get_spec_key_name, "check/path", ""
      expect(h.check_key_exists provider.get_spec_key_name).to eq true
      got_check = provider.check
      expect(got_check).to be_a_kind_of String
      expect(got_check).to eq "path"
    end

    it "get spec for a sinlge Hash check" do
      h.ensure_meta_exists provider.get_spec_key_name, "check/type", "short"
      got_check = provider.check
      expect(got_check).to be_a_kind_of Hash
      expect(got_check.include? "type").to eq true
      expect(got_check["type"]).to eq "short"
    end

    it "get spec for multiple Hash checks" do
      h.ensure_meta_exists provider.get_spec_key_name, "check/type", "short"
      h.ensure_meta_exists provider.get_spec_key_name, "check/type/min", "0"
      h.ensure_meta_exists provider.get_spec_key_name, "check/type/max", "5"
      got_check = provider.check
      expect(got_check.include? "type").to eq true
      expect(got_check.include? "type/min").to eq true
      expect(got_check.include? "type/max").to eq true
      expect(got_check["type"]).to eq "short"
      expect(got_check["type/min"]).to eq "0"
      expect(got_check["type/max"]).to eq "5"
    end

    it "get spec for a single check with multiple values" do
      exp_checks = {
        "check/enum/#0" => "one",
        "check/enum/#1" => "two",
        "check/enum/#2" => "three"
      }
      exp_checks.each do |k,v|
        h.ensure_meta_exists provider.get_spec_key_name, k, v
      end

      got_check = provider.check

      expect(got_check.include? "enum").to eq true
      expect(got_check.include? "enum/#0").to eq false
      expect(got_check["enum"]).to eq exp_checks.values
    end

    it "set spec for a single String check" do
      h.ensure_meta_is_missing provider.get_spec_key_name, "check/path"

      provider.check= "path"
      provider.flush

      expect(
        h.check_meta_exists provider.get_spec_key_name, "check/path"
      ).to eq true
      expect(
        h.key_get_meta provider.get_spec_key_name, "check/path"
      ).to eq ""
    end

    it "set spec for a single Hash check" do
      h.ensure_meta_is_missing provider.get_spec_key_name, "check/type"

      provider.check= {"type" => "long"}
      provider.flush

      expect(
        h.check_meta_exists provider.get_spec_key_name, "check/type"
      ).to eq true
      expect(
        h.key_get_meta provider.get_spec_key_name, "check/type"
      ).to eq "long"
    end

    it "set spec for multiple checks" do
      exp_check = {
        "type" => "long",
        "type/min" => "5",
        "type/max" => "10"
      }

      exp_check.keys.each do |c|
        h.ensure_meta_is_missing provider.get_spec_key_name, "check/#{c}"
      end

      provider.check= exp_check
      provider.flush

      exp_check.each do |c, v|
        expect(
          h.key_get_meta provider.get_spec_key_name, "check/#{c}"
        ).to eq v
      end
    end

    context "set spec to/from array values" do
      let(:spec_key) { provider.get_spec_key_name }
      let(:exp_check) do {
        "enum/#0" => "one",
        "enum/#1" => "two",
        "enum/#2" => "three"
      }
      end

      it "set spec for a single check with multiple values (array)" do
        exp_check.each do |c, v|
          h.ensure_meta_is_missing spec_key, "check/#{c}"
        end

        provider.check= {"enum" => exp_check.values}
        provider.flush

        exp_check.each do |c, v|
          expect(
            h.key_get_meta spec_key, "check/#{c}"
          ).to eq v
        end
        expect(h.key_get_meta spec_key, "check/enum").to eq "#2"
      end

      it "update spec for a single check with multiple values (array)" do
        { "enum"    => "#3",
          "enum/#0" => "x0",
          "enum/#1" => "x1",
          "enum/#2" => "x2",
          "enum/#3" => "x3"}.each do |k,v|
          h.ensure_meta_exists spec_key, "check/#{k}", v
        end

        provider.check= { "enum" => exp_check.values }
        provider.flush

        exp_check.each do |c, v|
          expect(
            h.key_get_meta spec_key, "check/#{c}"
          ).to eq v
        end
        expect(h.key_get_meta spec_key, "check/enum").to eq "#2"
        expect(
          h.check_meta_exists spec_key, "check/enum/#3"
        ).to eq false
      end

      it "set spec and removes all other 'check/' meta keys" do
        missing_check = { "enum" => "'one', 'two'",
          "enum/#0" => "x1",
          "enum/#1" => "x2",
          "type" => "short"
        }
        missing_check.each do |k,v|
          h.ensure_meta_exists spec_key, "check/#{k}", v
        end
        # to ensure, non 'check' metakeys are not touched
        h.ensure_meta_exists spec_key, "other/xy", "xxx"

        provider.check= "path"
        provider.flush

        missing_check.each do |k,v|
          expect(h.check_meta_exists spec_key, "check/#{k}").to eq false
        end
        expect(h.check_meta_exists spec_key, "check/path").to eq true

        expect(h.check_meta_exists spec_key, "other/xy").to eq true
        expect(h.key_get_meta spec_key, "other/xy").to eq "xxx"
      end
    end
  end
end
