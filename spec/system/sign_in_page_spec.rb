require "rails_helper"

# The view every unauthenticated visitor meets, and the one page nothing else in this layer
# asserts about: `paint_matcher_spec.rb` visits it only as a host for its own injected probe, and
# `authentication_spec.rb` goes to the confirmation page instead.
#
# What a browser adds here is that the form is visible rather than merely rendered. A class the
# stylesheet does not define leaves the submit button in the DOM with its label intact, so the
# request spec for `sessions#new` stays green while nobody can see the control.
RSpec.describe "The sign-in page", type: :system do
  before do
    visit new_session_path
  end

  it "paints the submit button" do
    expect(page).to paint "input[type=submit]"
  end

  # The other half of what a browser adds, and the half `paint` cannot reach: whether the form is
  # usable by someone who never sees it. `spec/support/axe.rb` owns which rules that means.
  it "has no accessibility violations" do
    expect(page).to be_accessible
  end

  # Named for what it asserts. That the answer is identical whether or not the address has an
  # account is `spec/requests/sessions_spec.rb`'s to prove, and nothing here reads the copy.
  it "paints the notice after a submission" do
    fill_in "email", with: "someone@example.com"
    click_button "Email me a sign-in link"

    expect(page).to have_css "#notice"
    expect(page).to paint "#notice"
  end
end
