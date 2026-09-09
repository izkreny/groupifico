require "rails_helper"

# Named for the pattern rather than for a screen, because the pattern is what this covers: one
# `AppFormBuilder#field` draws every form's fields, so proving it once proves it everywhere. Two
# screens host it, the way `paint_matcher_spec.rb` hosts its probe on the sign-in page - each
# screen's own spec belongs to the issue that redesigns it.
#
# Only what a browser adds. That the error element carries its id and text, that the control
# carries the aria pair, and that the summary reads what it reads are asserted in
# `spec/requests/addresses_spec.rb` and `spec/requests/groups_spec.rb`, which CI runs; per the
# duplication rule in `.agents/testing.md` they do not come back here. What is left is the part no
# request spec can see: whether daisyUI's `validator` actually paints from `aria-invalid`. Nothing
# in the markup names the error state, so a rule that stopped matching would leave every assertion
# below green at the request layer while the reader saw an unmarked field.
#
# `paint` is deliberately absent from the note: it composites an element's own *background* over
# its ancestor's, and the note has none, so it scores 1 for a message that reads perfectly well.
# The colour comparisons are what cover the note and the control instead.
RSpec.describe "A form field's errors", type: :system do
  # `:with_all_attributes` reaches the address through the traits that already name it: member's
  # associates `group, :with_all_attributes` and group's associates `address, :with_all_attributes`.
  let(:member) { create(:member, :owner, :with_all_attributes) }

  context "with an input" do
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

  # A `select` is a different daisyUI rule than an `input`, and the builder reaches it through a
  # different positional argument, so neither is evidence for the other. The member form is the
  # host: its sole owner going inactive raises the app's own `errors.add(:status, ...)`.
  context "with a select" do
    before do
      sign_in_as member.user

      visit edit_group_member_path(member.group, member)
      select "inactive", from: "member_status"
      click_button "Update Member"
    end

    it "colours the rejected select's border to match its message" do
      style_of = ->(selector, property) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property }

      expect(style_of["select#member_status", "borderTopColor"]).to eq style_of["#member_status_error", "color"]
    end

    it "has no accessibility violations" do
      expect(page).to be_accessible
    end
  end
end
