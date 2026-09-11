module AddressesHelper
  MAP_SEARCH_URL = "https://www.google.com/maps/search/"

  def address_choices(addresses)
    addresses.map { [ it.name, it.id ] }
  end

  # Every address in the app is a link that opens the reader's map application. A maps URL rather
  # than the `geo:` URI the wireframes name for mobile: both mobile platforms hand this host to
  # their own maps app, where no desktop browser has a handler for `geo:` at all. Coordinates win
  # where the record carries them, because a search on them lands on the place rather than near it.
  def address_map_url(address)
    query = if address.latitude && address.longitude
      "#{address.latitude},#{address.longitude}"
    else
      [ address.name, address.street_name, address.building_number, address.city ].compact_blank.join(", ")
    end

    "#{MAP_SEARCH_URL}?#{{ api: 1, query: }.to_query}"
  end
end
