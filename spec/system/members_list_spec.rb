require "rails_helper"

# Only what a browser adds. Who sees the "not signed in yet" mark, and for which members, is
# `spec/requests/members_spec.rb`'s assertion.
RSpec.describe "The members list", type: :system do
  it "paints the mark on a member who has never signed in, with no accessibility violations" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    added = create(:member, group: actor.group, user: create(:user, :with_full_profile, first_signed_in_at: nil))
    sign_in_as actor.user

    visit group_members_path(actor.group)

    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(added, :row)} .badge"
    expect(page).to be_accessible
  end
end
