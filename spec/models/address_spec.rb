require 'rails_helper'

RSpec.describe Address, type: :model do
  describe "(associations)" do
    it { is_expected.to have_one(:group) }
    it { is_expected.to have_many(:events) }
  end

  describe "(validations)" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:building_number).is_at_most(250) }
    it { is_expected.to validate_length_of(:city).is_at_most(250) }
    it { is_expected.to validate_length_of(:name).is_at_most(250) }
    it { is_expected.to validate_length_of(:street_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:postal_code).is_at_most(100) }
    it { is_expected.to validate_length_of(:state_code).is_at_most(50) }
    it { is_expected.to validate_length_of(:country_code).is_at_most(5) }
    it { is_expected.to validate_numericality_of(:latitude).allow_nil }
    it { is_expected.to validate_numericality_of(:longitude).allow_nil }
  end
end
