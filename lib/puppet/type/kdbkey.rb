

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

  newparam(:name) do
    desc "The fully qualified name of the key"

    puts "Type: param name"

    #validate do |value|
    #  puts "Type: param name, validate: #{value}"
    #  super
    #end
  end
end
