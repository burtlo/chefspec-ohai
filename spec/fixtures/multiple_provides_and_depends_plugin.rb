Ohai.plugin(:MultipleProvidesAndDepends) do
  provides 'private_network/private_ipv4', 'private_network/private_iface'

  depends 'network'

  collect_data(:default) do
    private_network Mash.new

    find_interface
    find_address
  end

  def find_interface
    network['interfaces'].each do |iface, attrs|
      next if attrs['state'] != 'up'
      if attrs['addresses'].keys.detect { |addr| addr =~ /^10\.|^192\.168/ }
        private_network Mash.new
        private_network['private_iface'] = iface
      end
    end
  end

  def find_address
    return if private_network.nil?
    private_iface = private_network['private_iface']
    possible_addresses = network['interfaces'][private_iface]['addresses'].keys
    private_network['private_ipv4'] = possible_addresses.detect { |addr| addr =~ /^10\.|^192\.168/ }
  end
end
