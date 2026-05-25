require 'rails_helper'

RSpec.describe Registration, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:event) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(reserved: 0, invited: 1, yes: 2, maybe: 3, no: 4).with_default(:reserved).validating }
  end
end
