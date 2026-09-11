module AddressesHelper
  MAP_SEARCH_URL = "https://www.google.com/maps/search/"

  def address_choices(addresses)
    addresses.map { [ it.name, it.id ] }
  end

  # Where the place is, in the one line frame 2f gives it - "Obala 14, 10000 Zagreb" - under the
  # name the screen states separately. The four fields that line names and no more: the coordinates
  # are machine values, and the country is on the form because a group can meet abroad rather than
  # because a reader of its own group's address needs telling which country it is in.
  #
  # `compact_blank` at both levels rather than one, because an address with a city and no street
  # would otherwise open on a comma and one with neither would be a bare comma.
  def address_summary(address)
    street = [ address.street_name, address.building_number ].compact_blank.join(" ")
    area   = [ address.postal_code, address.city ].compact_blank.join(" ")

    [ street, area ].compact_blank.join(", ")
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
