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
  # Paused *and* an owner, so the refusal is the status pre-check's rather than the owner rule's:
  # `edit?` is a write rule, and a paused member is refused the form itself.
  let(:member) { create(:member, :paused, :owner) }

  before do
    sign_in_as member.user
  end

  it "lands on the root page rather than on the form" do
    visit edit_group_path(member.group)

    expect(page).to have_current_path root_path
  end

  it "paints the alert, rather than merely rendering it" do
    visit edit_group_path(member.group)

    expect(page).to have_css "#alert"
    expect(page).to paint "#alert"
  end
end
