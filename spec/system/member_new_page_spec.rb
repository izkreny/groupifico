require "rails_helper"

# Only what a browser adds. Which fields the form draws for which member, and what a submission
# writes and mails, are `spec/requests/members_spec.rb`'s assertions.
RSpec.describe "The new member page", type: :system do
  # "Cancel | Send invite" fits the 288px row a 320px phone leaves: half of it each, less the 8px gap.
  it "shares one line equally between its two buttons on a 320px phone" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    sign_in_as actor.user
    resize_to [ 320, 700 ]

    visit new_group_member_path(actor.group)

    expect(page).to have_button "Send invite"
    expect(form_actions_layout).to eq({ "buttons" => [ [ "Cancel", 140 ], [ "Send invite", 140 ] ], "lines" => 1 })
  end

  context "when the address already belongs to the group" do
    before do
      actor = create(:member, :active, :members_administrator, :with_all_attributes)
      sign_in_as actor.user

      visit new_group_member_path(actor.group)
      fill_in "Email", with: actor.user.email
      click_button "Send invite"
    end

    it "colours the rejected field's border to match its message" do
      style_of = ->(selector, property) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property }

      expect(page).to have_text "Email already belongs to a member of this group"
      expect(style_of["input#member_email", "borderTopColor"]).to eq style_of["#member_email_error", "color"]
    end

    it "has no accessibility violations" do
      expect(page).to have_text "Email already belongs to a member of this group"
      expect(page).to be_accessible
    end
  end

  it "has no accessibility violations before anything is submitted" do
    actor = create(:member, :active, :owner, :with_all_attributes)
    sign_in_as actor.user

    visit new_group_member_path(actor.group)

    expect(page).to have_field "Email"
    expect(page).to be_accessible
  end

  it "adds the person and lands on their member page" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    sign_in_as actor.user

    visit new_group_member_path(actor.group)
    fill_in "Email", with: "new.person@example.com"
    click_button "Send invite"

    expect(page).to have_text "Member was successfully created."
  end
end
