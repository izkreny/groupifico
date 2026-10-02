require "rails_helper"

# Only what a browser adds. Who sees the "not signed in yet" mark, the count, Invite, the pencil
# and the toggle, which members are listed and in what order, are `spec/requests/members_spec.rb`'s
# assertions. What is left: that the tags and the buttons paint, that a dimmed row stays readable,
# which axe-core measures here since the dim is a theme colour with its own alpha, and that the
# name and the pencil land where they say.
RSpec.describe "The members list", type: :system do
  it "paints the mark on a member who has never signed in, with no accessibility violations" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    added = create(:member, group: actor.group, user: create(:user, :with_full_profile, first_signed_in_at: nil))
    sign_in_as actor.user

    visit group_members_path(actor.group)

    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(added, :row)} .badge"
    expect(page).to be_accessible
  end

  it "paints the roster in light, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(actor, :row)} .badge"
    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(paused, :row)}"
    expect(page).to be_accessible
  end

  it "paints the roster in dark, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(actor, :row)} .badge"
    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(paused, :row)}"
    expect(page).to be_accessible
  end

  it "lands on a member's screen from their name" do
    actor  = create(:member, :active, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)
    click_link target.full_name

    expect(page).to have_current_path group_member_path(actor.group, target)
    expect(page).to have_text target.email
  end

  it "lands on a member's edit form from the pencil" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)
    click_link "Edit #{target.full_name}"

    expect(page).to have_current_path edit_group_member_path(actor.group, target)
    expect(page).to have_button "Save member"
  end
end
