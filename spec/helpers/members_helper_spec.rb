require 'rails_helper'

RSpec.describe MembersHelper, type: :helper do
  describe "#member_choices" do
    it "pairs each member's full name with its id, in collection order" do
      first  = create(:member, user: create(:user, :with_full_profile, first_name: "Ada", last_name: "Lovelace"))
      second = create(:member, user: create(:user, :with_full_profile, first_name: "Alan", last_name: "Turing"))

      expect(helper.member_choices([ first, second ])).to eq [ [ "Ada Lovelace", first.id ], [ "Alan Turing", second.id ] ]
    end
  end
end
