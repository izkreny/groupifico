module AddressesHelper
  def address_choices(addresses)
    addresses.map { [ it.name, it.id ] }
  end
end
