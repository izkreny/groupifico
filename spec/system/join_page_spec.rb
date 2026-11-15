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

  it "paints the button that sends the confirmation link" do
    token = JoinLink.mint(create(:group, name: "Riverside Choir"))

    visit new_join_request_path(token:)

    expect(page).to paint "button[type=submit]"
  end

  context "when the form is submitted" do
    it "lands on the check-your-email page, which has no accessibility violations in light" do
      token = JoinLink.mint(create(:group, name: "Riverside Choir"))
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE
      visit new_join_request_path(token:)

      fill_in_join_request
      click_button "Send my confirmation link"

      expect(page).to have_css "h1", text: "Check your email"
      expect(rendered_colour_scheme).to eq "light"
      expect(page).to be_accessible
    end

    it "lands on the check-your-email page, which has no accessibility violations in dark" do
      token = JoinLink.mint(create(:group, name: "Riverside Choir"))
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE
      visit new_join_request_path(token:)

      fill_in_join_request
      click_button "Send my confirmation link"

      expect(page).to have_css "h1", text: "Check your email"
      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to be_accessible
    end

    # WHY: a mobile phone of the wrong shape, since the browser's own `required` and `type=email` checks stop a blank field or a malformed address before the server sees them.
    it "reveals the refused field's message and stays accessible" do
      token = JoinLink.mint(create(:group, name: "Riverside Choir"))
      resize_to ViewportHelper::MOBILE
      visit new_join_request_path(token:)

      fill_in_join_request(mobile_phone: "call me")
      click_button "Send my confirmation link"

      expect(page).to have_css "#join_request_mobile_phone_error", text: "Mobile phone is invalid"
      expect(page).to be_accessible
    end
  end

  private
    def fill_in_join_request(mobile_phone: "+385 91 123 4567")
      fill_in "First name", with: "Ana"
      fill_in "Last name", with: "Kovač"
      fill_in "Your email", with: "ana@example.com"
      fill_in "Mobile", with: mobile_phone
    end
end
