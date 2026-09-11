require "rails_helper"

# Only what a browser adds. Which of the two states a reader gets, and which controls each offers
# whom, is `spec/requests/groups_spec.rb`'s assertion, and per the duplication rule in
# `.agents/testing.md` none of it comes back here. The chrome above the screen - the mark, the
# switcher, the tabs - is `spec/system/group_shell_spec.rb`'s and is not repeated either.
#
# What no request spec can reach: whether either state paints at all, and whether "See all events"
# is a control a person can use that arrives where it says.
#
# The paint targets follow `spec/system/events_list_spec.rb`'s reasoning: the hero is a `base-200`
# card over the page's own `base-100`, and the first-run screen's own surfaces are the button and
# the note beneath it. `body` and anything carrying `bg-base-100` would composite to 1.0 in light
# and read as painting nothing.
RSpec.describe "The group home", type: :system do
  it "paints the hero in light, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  it "paints the hero in dark, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  # The first-run screen is the state a new group opens on, so it is the one a reader sees first and
  # the one worth proving paints. The note carries `bg-base-200` over the page's `base-100`, which
  # is what the matcher can judge here; the button is the call to action itself.
  it "paints the first-run screen, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(page).to have_text "Nothing in the diary"
    expect(page).to paint ".btn-primary"
    expect(page).to paint ".bg-base-200"
    expect(page).to be_accessible
  end

  # A Turbo navigation, which is the one thing no request spec asserts: that the link is usable and
  # lands where it says rather than merely carrying the right href.
  it "lands on the events list when See all events is used" do
    member = create(:member, :owner, group: create(:group))
    next_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    click_link "See all events"

    expect(page).to have_current_path group_events_path(member.group)
  end

  it "lands on the event form when the first-run call to action is used" do
    member = create(:member, :owner, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    click_link "New event"

    expect(page).to have_current_path new_group_event_path(member.group)
  end

  # Whether the hero fits at either width is `spec/system/events_list_spec.rb`'s assertion about
  # the same partial, so it is not asked again here.
  #
  # Copied from `spec/system/events_list_spec.rb`, where the same hero needs the same event: a
  # confirmed one, upcoming, with the times frozen out of Faker's reach so `Group#next_event`
  # answers it rather than whatever the factory rolled.
  def next_event_for(member)
    create(:event,
      group: member.group,
      creator: member,
      name: "Tuesday rehearsal",
      category: :rehearsal,
      status: :confirmed,
      address: create(:address, name: "Community Hall"),
      starts_at: 2.days.from_now.change(hour: 19),
      ends_at: 2.days.from_now.change(hour: 21))
  end
end
