
module Puppet
  Type.type(:kdbkey).provide :ruby do
    desc "kdb through libelektra Ruby API"

    @@have_kdb = true

    begin
      require 'kdb'
    rescue LoadError
      @@have_kdb = false
    end

    puts "ruby provider"

    # make this provider default for Linux systems
    defaultfor :kernel => :Linux
    # if we can load the 'kdb' extension
    confine :true => @@have_kdb

    if @@have_kdb
      puts "open kdb"
      @@db = Kdb.open
      @@ks = Kdb::KeySet.new
      @@db.get @@ks, "/"
    end

    @resource_key = nil

    def create
      puts "ruby create #{@resource[:name]}"
      @resource_key = Kdb::Key.new @resource[:name], value: @resource[:value]
      @@ks << @resource_key
    end

    def destroy
      puts "ruby destroy #{@resource[:name]}"
      @@ks.delete @resource[:name]
    end

    def exists?
      puts "ruby exists? #{@resource[:name]}"
      @resource_key = @@ks.lookup @resource[:name]
      return !@resource_key.nil?
    end

    def value
      puts "getting value #{@resource[:name]}"
      return @resource_key.value unless @resource_key.nil?
    end

    def value=(value)
      puts "setting value of #{@resource[:name]} to #{value}"
      @resource_key.value= value unless @resource_key.nil?
    end

    def meta
      puts "get meta value #{@resource[:name]}"
      #key.meta.to_h unless key.nil? ruby 1.9 does not have Enumerable.to_h :(
      res = Hash.new
      @resource_key.meta.each { |e| res[e.name] = e.value } unless @resource_key.nil?
      puts "meta: #{res}"
      return res
    end

    def meta=(value)
      puts "set meta of #{@resource[:name]}: #{value}"
      value.each { |k, v| @resource_key.set_meta k, v } unless @resource_key.nil?
    end

    def comments
      comments = ""
      first = true
      @resource_key.meta.each do |e| 
        if e.name.start_with? "comments/#"
          comments << "\n" unless first
          comments << e.value.sub(/^# /, '')
          first = false
        end
      end
      return comments
    end

    def comments=(value)
      if value.size == 0
        cm = @resource_key.meta.find_all do |e|
          e.name.start_with? "comments"
        end
        cm.each { |e| @resource_key.set_meta e.name, "" }
      else
        comment_lines = value.split "\n"
        puts "comment has #{comment_lines.size} lines"
        @resource_key.set_meta "comments", "##{comment_lines.size - 1}"
        comment_lines.each_with_index do |line, i|
          @resource_key.set_meta "comments/##{i}", "# #{line}"
        end
      end
    end

    #def clear
    #  super
    #  puts "ruby clear"
    #end

    def flush
      puts "ruby flush #{@resource[:name]}"
      @@db.set @@ks, "/"
    end

    def self.post_resource_eval
      puts "ruby post resource eval"
      @@db.close if @@have_kdb
    end

  end
end
