require "rails_helper"

# Only what a browser adds. Which controls the form draws for which reader, what the segments
# preselect and what a role box is described by are `spec/requests/members_spec.rb`'s assertions.
# This page is where the app's own `errors.add(:status, ...)` fires: its sole owner going inactive.
RSpec.describe "The member edit page", type: :system do
  context "when a submission is rejected" do
    before do
      member = create(:member, :owner, :with_all_attributes)
      sign_in_as member.user

      visit edit_group_member_path(member.group, member)
      find(".join input[type=radio][value='inactive']").click
      click_button "Save member"
    end

    it "has no accessibility violations" do
      expect(page).to have_css "#member_status_error"
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
      click_button "Save member"

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

    # Which names a role implies is `spec/models/role_spec.rb`'s; that ticking a box greys the rows
    # those names belong to, and that the grey lifts again, only happens in a browser.
    it "greys the narrower roles while owner is ticked, and lifts the grey once it is not" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, group: owner.group)
      sign_in_as owner.user

      visit edit_group_member_path(member.group, member)
      check "Owner"

      colour_of = ->(selector) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0])).color", selector }

      expect(page).to have_css "[data-implied]", count: 3
      expect(colour_of["[data-implied] label"]).not_to eq colour_of["[data-role-implications-target=role]:not([data-implied]) label"]

      uncheck "Owner"

      expect(page).to have_no_css "[data-implied]"
    end

    # A greyed box is presentation alone, so what it shows is what the form posts.
    it "keeps a greyed role the member already holds when the save is about something else" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, group: owner.group, roles: [ build(:role, name: "administrator"), build(:role, name: "events_administrator") ])
      sign_in_as owner.user

      visit edit_group_member_path(member.group, member)
      expect(page).to have_css "[data-implied]", count: 2
      find(".join input[type=radio][value='paused']").click
      click_button "Save member"

      expect(page).to have_text "Member was successfully updated."
      expect(member.reload.roles.map(&:name)).to contain_exactly "administrator", "events_administrator"
    end

    # axe-core measures the grey here: it is a colour with its own alpha, which
    # `ContrastHelper#text_contrast` reads as the opaque colour.
    it "keeps a greyed role readable in light" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, :administrator, group: owner.group)
      sign_in_as owner.user
      prefer_colour_scheme :light

      visit edit_group_member_path(member.group, member)

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to have_css "[data-implied]", count: 2
      expect(page).to be_accessible
    end

    it "keeps a greyed role readable in dark" do
      owner  = create(:member, :active, :owner, :with_all_attributes)
      member = create(:member, :active, :administrator, group: owner.group)
      sign_in_as owner.user
      prefer_colour_scheme :dark

      visit edit_group_member_path(member.group, member)

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to have_css "[data-implied]", count: 2
      expect(page).to be_accessible
    end
  end

  it "removes the member through the confirm sheet and lands on the roster" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit edit_group_member_path(actor.group, target)
    click_button "Remove"
    within("dialog[open]") { click_button "Remove" }

    expect(page).to have_current_path group_members_path(actor.group)
    expect(page).to have_text "Member was successfully destroyed."
    expect(Member.exists?(target.id)).to be false
  end
end
