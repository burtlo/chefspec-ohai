require 'spec_helper'

describe_ohai_plugin :NonDefaultCollectData do
  let(:plugin_file) { 'spec/fixtures/non_default_collect_data_plugin.rb' }
  let(:attribute_name) { 'application/version' }

  context 'linux data collection' do
    let(:platform) { 'linux' }

    it 'the attribute is correctly set' do
      expect(plugin_attribute(attribute_name)).to eq '3.0.0'
    end
  end

  context 'windows data collection' do
    let(:platform) { 'windows' }

    it 'the attribute is correctly set' do
      expect(plugin_attribute(attribute_name)).to eq '9.0.0'
    end
  end
end
