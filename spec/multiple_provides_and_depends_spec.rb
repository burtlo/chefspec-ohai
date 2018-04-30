require 'spec_helper'

describe_ohai_plugin :MultipleProvidesAndDepends do
  let(:plugin_file) { 'spec/fixtures/multiple_provides_and_depends_plugin.rb' }
  let(:first_attribute) { 'private_network/private_ipv4' }
  let(:second_attribute) { 'private_network/private_iface' }
  let(:dependent_attribute) { 'network' }

  it 'provides the first attribute' do
    expect(plugin).to provide_attribute(first_attribute)
  end

  it 'provides the second attribute' do
    expect(plugin).to provide_attribute(second_attribute)
  end

  it 'depends on another plugin' do
    expect(plugin).to depend_on_attribute(dependent_attribute)
  end

  context 'default data collection' do

    before do
      allow(plugin).to receive(:network).and_return(network_data)
    end

    let(:network_data) do
      {
        'interfaces' => {
          'lo' => {
            'state' => 'unknown',
            'addresses' => {
              '127.0.0.1' => {
                'family' => 'inet',
              },
            },
          },
          'eno1' => {
            'state' => 'up',
            'addresses' => {
              '147.75.106.151' => {
                'family' => 'inet',
              },
            },
          },
          'eno2' => {
            'state' => 'up',
            'addresses' => {
              '192.168.0.2' => {
                'family' => 'inet',
              },
            },
          },
        },
      }
    end

    it 'the first attribute is correctly set' do
      expect(plugin_attribute(second_attribute)).to eq('eno2')
    end

    it 'the second attribute is correctly set' do
      expect(plugin_attribute(first_attribute)).to eq('192.168.0.2')
    end
  end
end
