# encoding: UTF-8
##
# @file
#
# @brief
#
# @copyright BSD License (see LICENSE or http://www.libelektra.org)
#


# helper methods for testing the kdbkey providers

class KdbKeyProviderHelper
  attr :test_prefix
  attr :ks

  def initialize(_test_prefix, _ks = Kdb::KeySet.new)
    @test_prefix = _test_prefix
    @ks = _ks
  end

  def ensure_key_exists(keyname, value = "test")
    key = @ks.lookup keyname
    if key.nil?
      @ks << key = Kdb::Key.new(keyname)
    end
    key.value = value
  end

  def ensure_meta_exists(keyname, meta, value = "test")
    key = @ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new(keyname)
      @ks << key
    end
    key.set_meta meta, value
  end

  def ensure_comment_exists(keyname, comment = "test")
    key = @ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new keyname
      @ks << key
    end
    # delete old comment first
    key.meta.each do |e|
      key.del_meta e if e.name.start_with? COMMENT
    end
    lines = comment.split "\n"
    key[COMMENT] = "##{lines.size}"
    lines.each_with_index do |line, index|
      key[COMMENT+"/##{index}"] = line
    end
  end

  def ensure_key_is_missing(keyname)
    unless @ks.lookup(keyname).nil?
      @ks.delete keyname
    end
  end

  def ensure_meta_is_missing(keyname, meta)
    key = @ks.lookup keyname
    key.del_meta meta unless key.nil?
  end

  def ensure_comment_is_missing(keyname)
    key = @ks.lookup keyname
    unless key.nil?
      key.meta.each do |m|
        key.del_meta m if m.name.start_with? COMMENT
      end
    end
  end

  def check_key_exists(name)
    !@ks.lookup(name).nil?
  end

  def check_meta_exists(keyname, meta)
    key = @ks.lookup keyname
    unless key.nil?
      return key.has_meta? meta
    end
    false
  end

  def check_comment_exists(keyname)
    key = @ks.lookup keyname
    unless key.nil?
      return (key.has_meta?(COMMENT) or key.has_meta?(COMMENT+"/#0"))
    end
    false
  end

  def key_get_value(keyname)
    key = @ks.lookup keyname
    unless key.nil?
      return key.value
    end
    nil
  end

  def key_get_meta(keyname, meta)
    key = @ks.lookup keyname
    unless key.nil?
      return key[meta]
    end
    nil
  end

  def key_get_comment(keyname)
    comment = nil
    key = @ks.lookup keyname
    unless key.nil?
      key.meta.find_all do |e|
        #e.name.start_with? COMMENT+"/#"
        e.name =~ /#{COMMENT}+\/#\d+$/
      end.each do |c|
        comment = [] if comment.nil?
        if c.value.start_with? "#"
          comment << c.value[1..-1]
        else
          comment << c.value
        end
      end
      return comment.join "\n" unless comment.nil?
    end
    nil
  end
end


