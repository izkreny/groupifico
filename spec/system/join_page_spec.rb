require "rails_helper"

# The page a join link opens, which every holder of one lands on. What it shows and who reaches it are `spec/requests/join_requests_spec.rb`'s; what a browser adds is that the page passes axe, contrast of the group's name included, and that a long name wraps rather than running off a phone's screen.
RSpec.describe "The join page", type: :system do
  it "has no accessibility violations in light" do
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to be_accessible
  end

  it "has no accessibility violations in dark" do
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # WHY: #446 AC4 in the browser; an address over 250 characters is one the browser's own email check lets through, so the refusal is the server's.
  it "shows a refused address's error under the field, and the refused page passes axe" do
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)
    fill_in "Your email", with: "#{'a' * 240}@example.com"
    click_button "Email me a sign-in link"

    expect(page).to have_css "#user_email_error", text: "Email is too long"
    expect(page).to be_accessible
  end

  it "has no accessibility violations on the check-your-inbox page in light" do
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit join_request_sign_in_link_path

    expect(page).to have_css "h1", text: "Check your inbox"
    expect(page).to be_accessible
  end

  it "has no accessibility violations on the check-your-inbox page in dark" do
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit join_request_sign_in_link_path

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # WHY: #504 AC1 and AC2 in the browser, the button posting, the redirect landing on the membership it created, and Open reaching the group.
  it "takes a signed-in visitor who presses the button into the group" do
    sign_in_as create(:user)
    group = create(:group, name: "Riverside Choir")
    token = JoinLink.mint(group)
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)
    click_button "Ask to join Riverside Choir"
    expect(page).to have_text "You are already in this group."
    click_link "Open Riverside Choir"

    expect(page).to have_current_path group_path(group)
  end

  it "has no accessibility violations on the ask to join button in light" do
    sign_in_as create(:user)
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_button "Ask to join Riverside Choir"
    expect(page).to be_accessible
  end

  it "has no accessibility violations on the ask to join button in dark" do
    sign_in_as create(:user)
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # WHY: #447 AC4, each message a membership answers the page with, in both schemes.
  it "has no accessibility violations telling a member they are already in the group in light" do
    member = create(:member, :active, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_link "Open Riverside Choir"
    expect(page).to be_accessible
  end

  it "has no accessibility violations telling a member they are already in the group in dark" do
    member = create(:member, :active, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  it "has no accessibility violations telling a pending member they are waiting in light" do
    member = create(:member, :pending)
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_text "Your request to join is waiting for approval."
    expect(page).to be_accessible
  end

  it "has no accessibility violations telling a pending member they are waiting in dark" do
    member = create(:member, :pending)
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  it "has no accessibility violations telling a member who left in light" do
    member = create(:member, :inactive)
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_text "You left this group."
    expect(page).to be_accessible
  end

  it "has no accessibility violations telling a member who left in dark" do
    member = create(:member, :inactive)
    sign_in_as member.user
    token = JoinLink.mint(member.group)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # WHY: resized before visiting, for the reason `spec/system/sign_in_page_spec.rb` gives.
  it "breaks a group name word too long for the screen rather than scrolling sideways at phone width" do
    token = JoinLink.mint(create(:group, name: "Riverside Kammerchorgemeinschaftsvereinigungsorchester"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_css "h1", text: "Kammerchorgemeinschaftsvereinigungsorchester"
    expect(horizontal_overflow).to eq 0
  end

  # WHY: #368, the sweep's own pair of values.
  it "breaks a long one-word group name rather than scrolling sideways at phone width" do
    token = JoinLink.mint(create(:group, name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_css "h1", text: "Simpsoncalifragilisticexpialaciousannoyedgruntcious"
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word group name rather than scrolling sideways at phone width" do
    token = JoinLink.mint(create(:group, name: "The Extraordinarily Long Named Riverside Community Choir Of Greater Springfield"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_css "h1", text: "The Extraordinarily Long Named Riverside Community Choir Of Greater Springfield"
    expect(horizontal_overflow).to eq 0
  end
end
