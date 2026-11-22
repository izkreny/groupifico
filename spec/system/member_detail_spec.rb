require "rails_helper"

# Only what a browser adds. Which facts the screen states, and the pencil per reader, are
# `spec/requests/members_spec.rb`'s assertions. What is left: that the role badge and the contact
# card paint, that the screen, its description list included, has no accessibility violations,
# and the size its icons draw at.
RSpec.describe "The member detail page", type: :system do
  it "paints the member screen in light, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  it "paints the member screen in dark, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  # WHY: #368; the screen wraps a long name, email and mobile, and keeps the pencil and the Email and Call buttons inside it.
  it "wraps a long one-word name, email and mobile inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group, user: create(:user, first_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", last_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", email: "simpsoncalifragilisticexpialaciousannoyedgruntcious@example.com"))
    target.profile.update!(mobile_phone: "+38591234567890123456789012345678901234567890123")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(target)} a[aria-label='Edit']", "##{ActionView::RecordIdentifier.dom_id(target)}")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Email ']", "main .card-body")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Call ']", "main .card-body")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word name and mobile inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group, user: create(:user, first_name: "Maximilian Bartholomew Featherstonehaugh", last_name: "Montgomery Worthington Smythe"))
    target.profile.update!(mobile_phone: "+385 91 234 5678 extension 9012 the office desk")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(target)} a[aria-label='Edit']", "##{ActionView::RecordIdentifier.dom_id(target)}")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Email ']", "main .card-body")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Call ']", "main .card-body")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  # WHY: #368; Manages lists the member's events in `list-row`s, which break a long name inside the screen.
  it "wraps a long one-word managed event name inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group)
    create(:event, group: owner.group, creator: owner, manager: target, name: "SimpsoncalifragilisticexpialaciousannoyedgruntciousSimpsoncalifragilisticexpialaciousannoyedgruntcious")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(page).to have_css "#manages"
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word managed event name inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group)
    create(:event, group: owner.group, creator: owner, manager: target, name: "The Extraordinarily Long Named Spring Concert Of The Riverside Community Choir")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(page).to have_css "#manages"
    expect(horizontal_overflow).to eq 0
  end

  it "draws its edit, email and call icons at 20px" do
    reader = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :active, :with_all_attributes, group: reader.group)
    sign_in_as reader.user

    visit group_member_path(target.group, target)

    expect(page.evaluate_script(<<~JS)).to eq [ 20, 20, 20 ]
      [ "Edit", "Email ", "Call " ].map(label => document.querySelector(`main a[aria-label^='${label}'] svg`).getBoundingClientRect().width)
    JS
  end
end
