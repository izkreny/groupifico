require "rails_helper"

# Named for the pattern rather than for a screen, because the pattern is what this covers: one
# `AppFormBuilder#field` draws every form's fields, so proving it once proves it everywhere. The
# address edit screen is the host, the way `paint_matcher_spec.rb` hosts its probe on the sign-in
# page - the screen itself belongs to #255, and its own spec arrives with it.
#
# What a browser adds is that the error is *visible* where the frame puts it. `text-error` on the
# note and `input-error` on the control are classes the stylesheet has to define; an undefined one
# leaves the message in the DOM with its text intact, so a request spec asserting the 422 stays
# green while the reader sees an unmarked field and a summary telling them to fix it.
#
# `paint` is deliberately absent from the message example: it composites an element's own
# *background* over its ancestor's, and the note has none, so it scores 1 for a message that reads
# perfectly well. The colour comparison below is what covers the note instead.
RSpec.describe "A form field's errors", type: :system do
  # Owner of the group whose home address this is, which is what `AddressPolicy#update?` wants:
  # a group holding the address answers for it alone.
  let(:member) { create(:member, :owner, group: create(:group, address: create(:address, :with_all_attributes))) }

  before do
    sign_in_as member.user

    visit edit_address_path(member.group.address)
    fill_in "address_name", with: ""
    click_button "Update Address"
  end

  it "shows the message under the field that failed" do
    expect(page).to have_css "#address_name_error", text: "Name can't be blank"
  end

  it "colours the message apart from the label above it" do
    colour_of = ->(selector) { page.evaluate_script "getComputedStyle(document.querySelector(arguments[0])).color", selector }

    expect(colour_of["#address_name_error"]).not_to eq colour_of["label[for='address_name']"]
  end

  it "marks the failed control invalid and points it at the message" do
    expect(page).to have_css "input#address_name[aria-invalid='true'][aria-describedby='address_name_error']"
  end

  # Reads the border rather than the class list, because the class list is what looked right while
  # the border was untouched: `input-error` was being composed at runtime, so Tailwind never
  # compiled it and the control carried a class no stylesheet defined.
  it "colours the failed control's border apart from a control that passed" do
    border_of = ->(id) { page.evaluate_script "getComputedStyle(document.getElementById(arguments[0])).borderTopColor", id }

    expect(border_of["address_name"]).not_to eq border_of["address_city"]
  end

  it "paints the summary alert above the fields" do
    expect(page).to have_css "#error_explanation", text: "Please fix the highlighted fields."
    expect(page).to paint "#error_explanation"
  end

  it "keeps what the reader typed in the fields that passed" do
    expect(page).to have_field "address_city", with: member.group.address.city
  end

  it "has no accessibility violations" do
    expect(page).to be_accessible
  end
end
