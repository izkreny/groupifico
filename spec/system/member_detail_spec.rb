require "rails_helper"

# Only what a browser adds. Which facts the screen states, and the pencil per reader, are
# `spec/requests/members_spec.rb`'s assertions. What is left: that the role badge and the contact
# card paint, and that the screen, its description list included, has no accessibility violations.
RSpec.describe "The member detail page", type: :system do
  it "paints the member screen in light, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  it "paints the member screen in dark, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end
end
