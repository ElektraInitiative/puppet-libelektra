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
  def ensure_key_exists(ks, keyname, value = "test")
    key = ks.lookup keyname
    if key.nil?
      ks << key = Kdb::Key.new(keyname)
    end
    key.value = value
  end

  def ensure_meta_exists(ks, keyname, meta, value = "test")
    key = ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new(keyname)
      ks << key
    end
    key.set_meta meta, value
  end

  def ensure_comment_exists(ks, keyname, comment = "test")
    key = ks.lookup keyname
    if key.nil?
      key = Kdb::Key.new keyname
      ks << key
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

  def ensure_key_is_missing(ks, keyname)
    unless ks.lookup(keyname).nil?
      ks.delete keyname
    end
  end

  def ensure_meta_is_missing(ks, keyname, meta)
    key = ks.lookup keyname
    key.del_meta meta unless key.nil?
  end

  def ensure_comment_is_missing(ks, keyname)
    key = ks.lookup keyname
    unless key.nil?
      key.meta.each do |m|
        key.del_meta m if m.name.start_with? COMMENT
      end
    end
  end

  def check_key_exists(ks, name)
    !ks.lookup(name).nil?
  end

  def check_meta_exists(ks, keyname, meta)
    key = ks.lookup keyname
    unless key.nil?
      return key.has_meta? meta
    end
    false
  end

  def check_comment_exists(ks, keyname)
    key = ks.lookup keyname
    unless key.nil?
      return (key.has_meta?(COMMENT) or key.has_meta?(COMMENT+"/#0"))
    end
    false
  end

  def key_get_value(ks, keyname)
    key = ks.lookup keyname
    unless key.nil?
      return key.value
    end
    nil
  end

  def key_get_meta(ks, keyname, meta)
    key = ks.lookup keyname
    unless key.nil?
      return key[meta]
    end
    nil
  end

  def key_get_comment(ks, keyname)
    comment = nil
    key = ks.lookup keyname
    unless key.nil?
      key.meta.find_all do |e|
        e.name.start_with? COMMENT+"/#"
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


