require "rails_helper"

# Only what a browser adds. That the refusal redirects and that the message reaches the response
# body are proven in `spec/requests/groups_spec.rb`, and per the duplication rule in
# `.agents/testing.md` they do not come back here.
#
# What a request spec cannot reach is whether the alert is *visible*. Changing the flash partial's
# `alert alert-error` to a class the stylesheet does not define leaves the element in the DOM with
# its text intact, so every request spec stays green while a person sees nothing; the paint
# assertion below is what goes red. Measured, not assumed: that edit was made, both layers were
# run, and only this one failed.
RSpec.describe "Refusing a paused member", type: :system do
  # Paused *and* an owner, which is the only way to reach the form at all. `edit?` is a read, so
  # the status pre-check lets a paused member through it, and `GroupPolicy#edit?` then wants an
  # owner; `update?` is a write, so the same member is refused on submit. A paused non-owner never
  # sees the form, which is a different refusal and the request specs' to assert.
  let(:member) { create(:member, :paused, :owner, group: create(:group, name: "Original")) }

  before do
    sign_in_as member.user
  end

  it "lands on the root page rather than the form that refused the edit" do
    visit edit_group_path(member.group)
    fill_in "group_name", with: "Renamed"
    click_button "Update Group"

    expect(page).to have_current_path root_path
  end

  it "paints the alert, rather than merely rendering it" do
    visit edit_group_path(member.group)
    fill_in "group_name", with: "Renamed"
    click_button "Update Group"

    expect(page).to have_css "#alert"
    expect(page).to paint "#alert"
  end
end
