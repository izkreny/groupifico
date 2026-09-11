require 'rails_helper'

RSpec.describe AddressesHelper, type: :helper do
  describe "#address_choices" do
    it "pairs each address's name with its id, in collection order" do
      hall   = build_stubbed(:address, name: "Village Hall")
      studio = build_stubbed(:address, name: "Studio B")

      expect(helper.address_choices([ hall, studio ])).to eq [ [ "Village Hall", hall.id ], [ "Studio B", studio.id ] ]
    end
  end

  describe "#address_map_url" do
    it "searches on the coordinates where the record carries them" do
      address = build_stubbed(:address, name: "Village Hall", latitude: 51.5, longitude: -0.12)

      expect(helper.address_map_url(address)).to eq "https://www.google.com/maps/search/?api=1&query=51.5%2C-0.12"
    end

    it "searches on the written address where it does not" do
      address = build_stubbed(:address, name: "Village Hall", street_name: "High Street", building_number: "2", city: "Ur", latitude: nil, longitude: nil)

      expect(helper.address_map_url(address)).to eq "https://www.google.com/maps/search/?api=1&query=Village+Hall%2C+High+Street%2C+2%2C+Ur"
    end
  end
end
