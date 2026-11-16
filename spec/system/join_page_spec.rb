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

  # WHY: resized before visiting, for the reason `spec/system/sign_in_page_spec.rb` gives.
  it "breaks a group name word too long for the screen rather than scrolling sideways at phone width" do
    token = JoinLink.mint(create(:group, name: "Riverside Kammerchorgemeinschaftsvereinigungsorchester"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_css "h1", text: "Kammerchorgemeinschaftsvereinigungsorchester"
    expect(horizontal_overflow).to eq 0
  end
end
