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

  describe "#account_deletion_message" do
    it "names the one group the reader leaves" do
      band = build_stubbed(:group, name: "Ninth Street Band")

      expect(helper.account_deletion_message([ band ]))
        .to eq "You leave Ninth Street Band and every registration goes with you. This can't be undone."
    end

    it "names every group the reader leaves" do
      choir = build_stubbed(:group, name: "Riverside Choir")
      band  = build_stubbed(:group, name: "Ninth Street Band")

      expect(helper.account_deletion_message([ choir, band ]))
        .to eq "You leave Riverside Choir and Ninth Street Band and every registration goes with you. This can't be undone."
    end

    it "drops the leave clause when there is no group to leave" do
      expect(helper.account_deletion_message([]))
        .to eq "Every registration goes with you. This can't be undone."
    end
  end
end
