require 'rails_helper'

RSpec.describe MembersHelper, type: :helper do
  describe "#member_choices" do
    # The names run backwards through the alphabet on purpose, so an implementation that sorted
    # instead of preserving the collection's order fails here rather than passing by coincidence.
    # `create` is what `:with_full_profile` needs: it hangs the profile off an `after(:create)`.
    it "pairs each member's full name with its id, in collection order" do
      zimmer   = create(:member, user: create(:user, :with_full_profile, first_name: "Zoe", last_name: "Zimmer"))
      lovelace = create(:member, user: create(:user, :with_full_profile, first_name: "Ada", last_name: "Lovelace"))

      expect(helper.member_choices([ zimmer, lovelace ])).to eq [ [ "Zoe Zimmer", zimmer.id ], [ "Ada Lovelace", lovelace.id ] ]
    end
  end
end
