require "rails_helper"

# A `select` is a different daisyUI rule than an `input`, and the builder reaches it through a
# different positional argument, so neither is evidence for the other. This page is where the
# app's own `errors.add(:status, ...)` fires: its sole owner going inactive.
RSpec.describe "The member edit page", type: :system do
  context "when a submission is rejected" do
    before do
      member = create(:member, :owner, :with_all_attributes)
      sign_in_as member.user
      prefer_colour_scheme :light

      visit edit_group_member_path(member.group, member)
      select "inactive", from: "member_status"
      click_button "Update Member"
    end

    it "colours the rejected select's border to match its message" do
      style_of = ->(selector, property) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property }

      expect(style_of["select#member_status", "borderTopColor"]).to eq style_of["#member_status_error", "color"]
    end

    it "has no accessibility violations in light" do
      expect(rendered_colour_scheme).to eq "light"
      expect(page).to be_accessible
    end
  end

  context "when an owner edits a member's roles" do
    it "revokes every role once every box is unticked" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, group: owner.group, roles: [ build(:role, name: "administrator"), build(:role, name: "events_administrator") ])
      sign_in_as owner.user

      visit edit_group_member_path(member.group, member)
      uncheck "Administrator"
      uncheck "Events administrator"
      click_button "Update Member"

      expect(page).to have_text "Member was successfully updated."
      expect(member.reload.roles).to be_empty
    end

    it "has no accessibility violations" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, :events_administrator, group: owner.group)
      sign_in_as owner.user

      visit edit_group_member_path(member.group, member)

      expect(page).to have_checked_field "Events administrator"
      expect(page).to be_accessible
    end
  end
end
