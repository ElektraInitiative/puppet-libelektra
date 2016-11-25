require 'spec_helper'
describe 'libelektra' do
  context 'with default values for all parameters' do
    it { should contain_class('libelektra') }
  end
end
