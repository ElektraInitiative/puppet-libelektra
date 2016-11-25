
module Puppet
  Type.type(:kdbkey).provide :kdb do
    desc "kdb through kdb command"

    #require 'kdb'

    puts "kdb provider"

    #commands :kdb => "kdb"
    confine :true => false

    def create
      #puts "kdb create"
      self.value=(@resource[:value])
    end

    def destroy
      #puts "kdb destroy"
      kdb ["rm", @resource[:name]]
    end

    def exists?
      #puts "kdb exists? #{self.name}"
      output = execute([command(:kdb), "get", @resource[:name]],
                               :failonfail => false)
      #puts "output: #{output}, #{output.exitstatus}"
      output.exitstatus == 0
    end

    def value 
      #puts "getting value"
      output = kdb ["get", @resource[:name]]
      output[-1] = ''
      output
    end

    def value=(value)
      #puts "setting value to #{value}"
      kdb(["set", @resource[:name], value])
    end

  end
end
