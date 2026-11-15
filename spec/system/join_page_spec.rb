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

  # WHY: resized before visiting, for the reason `spec/system/sign_in_page_spec.rb` gives.
  it "breaks a group name word too long for the screen rather than scrolling sideways at phone width" do
    token = JoinLink.mint(create(:group, name: "Riverside Kammerchorgemeinschaftsvereinigungsorchester"))
    resize_to ViewportHelper::MOBILE

    visit new_join_request_path(token:)

    expect(page).to have_css "h1", text: "Kammerchorgemeinschaftsvereinigungsorchester"
    expect(horizontal_overflow).to eq 0
  end
end
