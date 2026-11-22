require "rails_helper"

# Frame 9k's screen: whether it paints and where its links land. What it draws for which reader is
# `spec/requests/addresses_spec.rb`'s, and Cancel and Save back onto it belong to the correction
# form's own file, `spec/system/address_edit_page_spec.rb`.
RSpec.describe "The place screen", type: :system do
  # `:with_all_attributes` reaches the address through the traits that already name it: member's
  # associates `group, :with_all_attributes` and group's associates `address, :with_all_attributes`.
  let(:member) { create(:member, :owner, :with_all_attributes) }

  it "paints Correct, with no accessibility violations" do
    sign_in_as member.user

    visit address_path(member.group.address)

    expect(page).to paint "#address_#{member.group.address.id} .btn"
    expect(page).to be_accessible
  end

  it "paints Correct in dark, with no accessibility violations" do
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit address_path(member.group.address)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "#address_#{member.group.address.id} .btn"
    expect(page).to be_accessible
  end

  # WHY: #368; the screen wraps a long place name, street, area, home group's name and Used by event name, and keeps Correct and the map link inside it.
  it "wraps a long one-word place, street, area, group and event name inside the screen on a phone" do
    address = create(:address, name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", street_name: "SimpsoncalifragilisticexpialaciousannoyedgruntciousSimpsoncalifragilisticexpialaciousannoyedgruntcious", city: "SimpsoncalifragilisticexpialaciousannoyedgruntciousSimpsoncalifragilisticexpialaciousannoyedgruntcious")
    owner = create(:member, :active, :owner, group: create(:group, name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", address:))
    create(:event, group: owner.group, creator: owner, address:, name: "SimpsoncalifragilisticexpialaciousannoyedgruntciousSimpsoncalifragilisticexpialaciousannoyedgruntcious")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit address_path(address)

    expect(gap_to_row_end("#address_#{address.id} a.btn", "#address_#{address.id}")).to be >= 0
    expect(gap_to_row_end("#address_#{address.id} address a", "#address_#{address.id}")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word place, street, area, group and event name inside the screen on a phone" do
    address = create(:address, name: "The Extraordinarily Long Named Community Hall Of Greater Springfield", street_name: "The Extraordinarily Long Named Avenue Of The Riverside Community", city: "The Extraordinarily Long Named City Of Greater Springfield In The Valley")
    owner = create(:member, :active, :owner, group: create(:group, name: "The Extraordinarily Long Named Riverside Community Choir Of Greater Springfield", address:))
    create(:event, group: owner.group, creator: owner, address:, name: "The Extraordinarily Long Named Spring Concert Of The Riverside Community Choir")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit address_path(address)

    expect(gap_to_row_end("#address_#{address.id} a.btn", "#address_#{address.id}")).to be >= 0
    expect(gap_to_row_end("#address_#{address.id} address a", "#address_#{address.id}")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "lands on the correction form from Correct" do
    sign_in_as member.user

    visit address_path(member.group.address)
    click_link "Correct"

    expect(page).to have_current_path edit_address_path(member.group.address)
  end

  it "lands on an event from Used by" do
    event = create(:event, group: member.group, address: member.group.address, name: "Tuesday rehearsal")
    sign_in_as member.user

    visit address_path(member.group.address)
    click_link "Tuesday rehearsal"

    expect(page).to have_current_path group_event_path(member.group, event)
  end
end
