require "rails_helper"

RSpec.describe GroupsHelper, type: :helper do
  describe "#group_type_choices" do
    it "offers the three types in the order frame 2e fixes, not the enum's" do
      expect(helper.group_type_choices).to eq [ [ "Choir", "choir" ], [ "Band", "band" ], [ "General", "general" ] ]
    end

    # The check that replaces a sorting hook for a fourth type: the only screen that sets
    # `group_type` reads this list, so a type added to `Group` and not placed here would simply
    # never be offered. Watched failing with `choir` removed from the list.
    it "covers every type the model defines" do
      expect(helper.group_type_choices.map(&:last)).to match_array Group.group_types.keys
    end
  end
end
