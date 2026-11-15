require "rails_helper"

# The page a join request's emailed link opens. What it shows and who reaches it are `spec/requests/join_request_confirmations_spec.rb`'s; what a browser adds is that the page passes axe and that a long group name wraps rather than running off a phone's screen.
RSpec.describe "The join request confirmation page", type: :system do
  it "has no accessibility violations in light" do
    token = JoinRequest.mint(join_link: create(:join_link, group: create(:group, name: "Riverside Choir")), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit join_request_confirmation_path(token:)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to be_accessible
  end

  it "has no accessibility violations in dark" do
    token = JoinRequest.mint(join_link: create(:join_link, group: create(:group, name: "Riverside Choir")), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit join_request_confirmation_path(token:)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # WHY: resized before visiting, for the reason `spec/system/sign_in_page_spec.rb` gives.
  it "breaks a group name word too long for the screen rather than scrolling sideways at phone width" do
    token = JoinRequest.mint(join_link: create(:join_link, group: create(:group, name: "Riverside Kammerchorgemeinschaftsvereinigungsorchester")), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")
    resize_to ViewportHelper::MOBILE

    visit join_request_confirmation_path(token:)

    expect(page).to have_css "h1", text: "Kammerchorgemeinschaftsvereinigungsorchester"
    expect(horizontal_overflow).to eq 0
  end
end
