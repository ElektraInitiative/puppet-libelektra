

Puppet::Type.newtype(:kdbkey) do
  @doc = %q{Manipulate libelekra keys
    TODO: finish this docu
  }

  ensurable

  newproperty(:value) do
    desc "The value of the key"
    puts "Type: property value"

    #validate do |value|
    #  puts "Type: property value, validate: #{value}"
    #  super
    #end
  end

  newproperty(:meta) do
    desc "metadata of this key"
    
    validate do |meta|
      if !meta.is_a? Hash
        raise ArgumentError, "Hash required"
      else
        super meta
      end
    end
  end

  newproperty(:comments) do
    desc "comments for this key"

  end

  newparam(:name) do
    desc "The fully qualified name of the key"

    puts "Type: param name"

    #validate do |value|
    #  puts "Type: param name, validate: #{value}"
    #  super
    #end
  end
end
