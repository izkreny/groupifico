require "rails_helper"

RSpec.describe "Browser smoke", type: :system do
  it "renders the sign-in page in a real browser" do
    visit new_session_path

    expect(page).to have_css "h1", text: "Sign in"
    expect(page).to have_button "Email me a sign-in link"
  end
end
