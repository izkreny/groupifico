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

  # The third thing only a browser knows, and the one neither matcher above reaches: a `nowrap`
  # flex item keeps its box inside the column while its text runs off the screen, so `paint` is
  # happy, axe is quiet, and the reader scrolls sideways. `ViewportHelper#horizontal_overflow`
  # carries the measurement that put this here.
  #
  # Resized and then visited again, never resized on a page already laid out: narrowing an open
  # page raises a vertical scrollbar without reflowing what is under it, and the 15px gutter reads
  # as overflow. `spec/system/groups_index_spec.rb` states its width before visiting for the same
  # reason, and this is the order every width example in the suite keeps.
  it "does not scroll sideways at phone width" do
    resize_to ViewportHelper::MOBILE
    visit new_session_path

    expect(horizontal_overflow).to eq 0
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
