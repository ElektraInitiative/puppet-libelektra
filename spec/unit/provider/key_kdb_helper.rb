# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#

require_relative 'key_ruby_helper.rb'

class KdbKeyProviderHelperKDB < KdbKeyProviderHelper
  # alias methods from kdb_ruby_helper
  # this allows us to wrap these methods
  #
  alias ks_ensure_key_exists ensure_key_exists
  alias ks_ensure_meta_exists ensure_meta_exists
  alias ks_ensure_comment_exists ensure_comment_exists
  alias ks_ensure_key_is_missing ensure_key_is_missing
  alias ks_ensure_meta_is_missing ensure_meta_is_missing
  alias ks_ensure_comment_is_missing ensure_comment_is_missing
  alias ks_check_key_exists check_key_exists
  alias ks_check_meta_exists check_meta_exists
  alias ks_check_comment_exists check_comment_exists
  alias ks_key_get_value key_get_value
  alias ks_key_get_meta key_get_meta
  alias ks_key_get_comment key_get_comment

  def initialize(test_prefix)
    super test_prefix
  end

  def do_on_kdb
    raise ArgumentError, "block required" unless block_given?

    Kdb.open do |kdb|
      # make cascading
      @test_prefix.gsub!(/^\w+\//, '/')
      @ks = Kdb::KeySet.new
      kdb.get @ks, @test_prefix
      result = yield
      kdb.set @ks, @test_prefix
      return result
    end
  end


  def ensure_key_exists(keyname, value = "test")
    do_on_kdb do
      ks_ensure_key_exists keyname, value
    end
  end

  def ensure_meta_exists(keyname, meta, value = "test")
    do_on_kdb do
      ks_ensure_meta_exists keyname, meta, value
    end
  end

  def ensure_comment_exists(keyname, comment = "test")
    do_on_kdb do
      ks_ensure_comment_exists keyname, comment
    end
  end

  def ensure_key_is_missing(keyname)
    do_on_kdb do
      ks_ensure_key_is_missing keyname
    end
  end

  def ensure_meta_is_missing(keyname, meta)
    do_on_kdb do
      ks_ensure_meta_is_missing keyname, meta
    end
  end

  def ensure_comment_is_missing(keyname)
    do_on_kdb do
      ks_ensure_comment_is_missing keyname
    end
  end

  def check_key_exists(name)
    do_on_kdb do
      ks_check_key_exists name
    end
  end

  def check_meta_exists(keyname, meta)
    do_on_kdb do
      ks_check_meta_exists keyname, meta
    end
  end

  def check_comment_exists(keyname)
    do_on_kdb do
      ks_check_comment_exists keyname
    end
  end

  def key_get_value(keyname)
    do_on_kdb do
      ks_key_get_value keyname
    end
  end

  def key_get_meta(keyname, meta)
    do_on_kdb do
      ks_key_get_meta keyname, meta
    end
  end

  def key_get_comment(keyname)
    do_on_kdb do
      ks_key_get_comment keyname
    end
  end

end

