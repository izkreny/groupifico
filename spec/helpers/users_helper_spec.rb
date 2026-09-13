require 'rails_helper'

RSpec.describe UsersHelper, type: :helper do
  describe "#solely_owned_groups_message" do
    it "names the one group and says what to do about it" do
      choir = build_stubbed(:group, name: "Riverside Choir")

      expect(helper.solely_owned_groups_message([ choir ]))
        .to eq "You still own Riverside Choir. Give another member the owner role first."
    end

    it "names every group, because the reader has to hand each one over" do
      choir = build_stubbed(:group, name: "Riverside Choir")
      band  = build_stubbed(:group, name: "Ninth Street Band")

      expect(helper.solely_owned_groups_message([ choir, band ]))
        .to eq "You still own Riverside Choir and Ninth Street Band. Give another member the owner role first."
    end
  end
end
