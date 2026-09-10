require 'rails_helper'

RSpec.describe AddressesHelper, type: :helper do
  describe "#address_choices" do
    it "pairs each address's name with its id, in collection order" do
      hall   = create(:address, name: "Village Hall")
      studio = create(:address, name: "Studio B")

      expect(helper.address_choices([ hall, studio ])).to eq [ [ "Village Hall", hall.id ], [ "Studio B", studio.id ] ]
    end
  end
end
