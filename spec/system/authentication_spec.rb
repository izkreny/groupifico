require "rails_helper"

RSpec.describe "Authentication", type: :system do
  # The one spec that pays for the whole cycle in the browser, so the flow every other spec skips
  # by setting the cookie is still covered somewhere.
  it "signs a member in through the emailed link" do
    member = create(:member)

    sign_in_through_the_browser member.user

    expect(page).to have_current_path root_path
  end

  # Guards the helper every other system spec depends on: a cookie the browser rejects would make
  # each of them fail as though its own subject were broken.
  it "signs in without the browser when the cookie helper is used" do
    member = create(:member)

    sign_in_as member.user
    visit root_path

    # Positive rather than "not the sign-in page": a negation immediately after `visit` can be
    # satisfied before the navigation resolves, which is what `Capybara/RSpec/
    # NegationMatcherAfterVisit` exists to catch. It caught this line.
    expect(page).to have_current_path root_path
  end
end
