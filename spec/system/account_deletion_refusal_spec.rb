require "rails_helper"

# Only what a browser adds. That the refusal redirects, that the account survives it, that the
# alert's text names the group and that the account screen carries the block are all proven in
# `spec/requests/user_spec.rb`, and per the duplication rule in `.agents/testing.md` none of them
# comes back here.
#
# What a request spec cannot reach is whether either message is *visible*. Both elements keep their
# text in the DOM under a class the stylesheet never compiled, so every request spec stays green
# while a person sees nothing; the paint assertions are what go red. Measured, not assumed: the
# block's `alert alert-error` was swapped for a class Tailwind never compiled, both layers were
# run, and only this one failed, at a contrast ratio of 1. Same argument, and the same shape, as
# `spec/system/group_refusal_spec.rb` makes from the group's end.
#
# `be_accessible` is the standing assertion `.agents/testing.md` puts on every spec covering a
# screen, and the matcher's own failure is watched in `spec/system/axe_matcher_spec.rb` rather than
# re-established here.
RSpec.describe "Refusing to delete a group's last owner", type: :system do
  include ActionView::RecordIdentifier

  let(:member) { create(:member, :owner, group: create(:group, name: "Riverside Choir")) }

  before do
    sign_in_as member.user

    visit user_path
  end

  it "paints the block naming the group still owned" do
    expect(page).to have_css "#solely_owned_groups"
    expect(page).to paint "#solely_owned_groups"
  end

  it "has no accessibility violations" do
    expect(page).to be_accessible
  end

  it "paints the alert when the sheet is confirmed" do
    within("##{dom_id(member.user, :confirm_delete)}_form") { click_button "Delete my account" }
    within(".modal-action") { click_button "Delete my account" }

    expect(page).to have_css "#alert"
    expect(page).to paint "#alert"
  end
end
