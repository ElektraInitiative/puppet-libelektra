
module Puppet
  Type.type(:kdbkey).provide :libelektra do
    desc "kdb through libelektra Ruby API"

    require 'kdb'

    puts "libelektra provider"

    #confine :true => true
    #confine :exists => "/etc/debian_version"
    confine :true => true

    def create
      puts "libelektra create"
      Kdb.open do |db|
        ks = Kdb::KeySet.new
        db.get ks, "/"
        key = Kdb::Key.new @resource[:name], value: @resource[:value]
        ks << key
        db.set ks, "/"
      end
    end

    def destroy
      puts "libelektra destroy"
      Kdb.open do |db|
        ks = Kdb::KeySet.new
        db.get ks, "/"
        ks.delete @resource[:name]
        db.set ks, "/"
      end
    end

    def exists?
      puts "libelektra exists?"
      Kdb.open do |db|
        ks =  Kdb::KeySet.new
        db.get ks, "/"
        key = ks.lookup @resource[:name]
        return !key.nil?
      end
    end

    def value
      puts "getting value"
      Kdb.open do |db|
        ks = Kdb::KeySet.new
        db.get ks, "/"
        key = ks.lookup @resource[:name]
        return key.value unless key.nil?
      end
    end

    def value=(value)
      puts "setting value to #{value}"
      Kdb.open do |db|
        ks = Kdb::KeySet.new
        db.get ks, "/"
        key = ks.lookup @resource[:name]
        if !key.nil?
          key.value= value
          db.set ks, "/"
        end
      end
    end

  end
end
