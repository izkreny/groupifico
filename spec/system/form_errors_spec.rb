require "rails_helper"

# Named for the pattern rather than for a screen, because the pattern is what this covers: one
# `AppFormBuilder#field` draws every form's fields, so proving it once proves it everywhere. The
# address edit screen is the host, the way `paint_matcher_spec.rb` hosts its probe on the sign-in
# page - the screen itself belongs to #255, and its own spec arrives with it.
#
# Only what a browser adds. That the error element carries its id and text, that the control
# carries the aria pair, and that the summary reads what it reads are asserted in
# `spec/requests/addresses_spec.rb`, which CI runs; per the duplication rule in
# `.agents/testing.md` they do not come back here. What is left is the part no request spec can
# see: whether those classes paint. `text-error` and `input-error` are classes the stylesheet has
# to define, and an undefined one leaves the markup intact while the reader sees an unmarked field
# under a summary telling them to fix it.
#
# `paint` is deliberately absent from the note: it composites an element's own *background* over
# its ancestor's, and the note has none, so it scores 1 for a message that reads perfectly well.
# The colour comparisons are what cover the note and the control instead.
RSpec.describe "A form field's errors", type: :system do
  # `:with_all_attributes` reaches the address through the traits that already name it: member's
  # associates `group, :with_all_attributes` and group's associates `address, :with_all_attributes`.
  let(:member) { create(:member, :owner, :with_all_attributes) }

  before do
    sign_in_as member.user

    visit edit_address_path(member.group.address)
    fill_in "address_name", with: ""
    fill_in "address_city", with: "Springfield"
    click_button "Update Address"
  end

  it "colours the message apart from the label above it" do
    colour_of = ->(selector) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0])).color", selector }

    expect(colour_of["#address_name_error"]).not_to eq colour_of["label[for='address_name']"]
  end

  # Reads the border rather than the class list, because the class list is what looked right while
  # the border was untouched: `input-error` was being composed at runtime, so Tailwind never
  # compiled it and the control carried a class no stylesheet defined.
  it "colours the failed control's border apart from a control that passed" do
    border_of = ->(id) { page.evaluate_script "getComputedStyle(document.getElementById(arguments[0])).borderTopColor", id }

    expect(border_of["address_name"]).not_to eq border_of["address_city"]
  end

  it "paints the summary alert above the fields" do
    expect(page).to paint "#error_explanation"
  end

  # A literal the reader typed, so a form re-rendered from the record rather than from the
  # submitted params fails here. Reading the stored city back instead would pass either way.
  it "keeps what the reader typed in the fields that passed" do
    expect(page).to have_field "address_city", with: "Springfield"
  end

  it "has no accessibility violations" do
    expect(page).to be_accessible
  end
end
