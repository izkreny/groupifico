require "rails_helper"

# A `select` is a different daisyUI rule than an `input`, and the builder reaches it through a
# different positional argument, so neither is evidence for the other. This page is where the
# app's own `errors.add(:status, ...)` fires: its sole owner going inactive.
RSpec.describe "The member edit page", type: :system do
  let(:member) { create(:member, :owner, :with_all_attributes) }

  context "when a submission is rejected" do
    before do
      sign_in_as member.user

      visit edit_group_member_path(member.group, member)
      select "inactive", from: "member_status"
      click_button "Update Member"
    end

    it "colours the rejected select's border to match its message" do
      style_of = ->(selector, property) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property }

      expect(style_of["select#member_status", "borderTopColor"]).to eq style_of["#member_status_error", "color"]
    end

    it "has no accessibility violations" do
      expect(page).to be_accessible
    end
  end
end
