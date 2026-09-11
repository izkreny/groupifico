require "rails_helper"

# Only what a browser adds. Which pieces of the card a given reader sees - the question for an
# invited member, the pills for nobody paused, the tags for everyone - is
# `spec/requests/events_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md`
# it does not come back here.
#
# What no request spec can reach is whether the three pieces paint at all, whether the lit pill is
# distinguishable from its neighbours, and where pressing one lands.
#
# The paint targets are chosen for surfaces the matcher can judge: the hero carries a `base-200`
# surface over the page's own `base-100`, and the tags and the pills carry theirs over the hero's.
# `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than
# the class that asks for it - with the class in the selector, an untinted hero fails as "does not
# exist" instead of as the ratio of 1 it actually paints.
RSpec.describe "The events list", type: :system do
  it "paints the hero card, its count tags and the lit pill, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(page).to paint ".card"
    expect(page).to paint ".badge"
    expect(page).to paint ".join .btn-primary"
    expect(page).to be_accessible
  end

  it "paints the same three in dark" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(page).to paint ".join .btn-primary"
    expect(page).to be_accessible
  end

  # The card is drawn for a phone and the pills are a `join` of three, so whether the row of them
  # fits beside the tags is geometry: the markup is identical at both widths and no request spec
  # can tell the two apart.
  it "fits the card inside the page at both widths" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :invited)
    sign_in_as member.user

    [ ViewportHelper::MOBILE, ViewportHelper::DESKTOP ].each do |viewport|
      resize_to viewport
      visit group_events_path(member.group)

      expect(overflowing?).to be false
    end
  end

  # Where a pressed pill lands is `RegistrationsController#update`'s answer, not this screen's, and
  # it is the first of the open questions on #246: the reader leaves the list for the registration
  # it wrote. Asserted as it behaves rather than as the card would want it.
  it "writes the answer and lands where the update sends the reader" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    event = next_event_for(member)
    registration = create(:registration, event:, member:, status: :invited)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)
    click_button "Yes"

    expect(page).to have_current_path group_event_registration_path(member.group, event, registration)
    expect(registration.reload).to be_yes
  end

  # The select is this screen's title and its filter at once, so two things about it need a
  # browser: that the pill paints as a surface of its own over the page, which no class assertion
  # can tell from a pill that compiled to nothing, and that changing it navigates - the control
  # carries no submit button, so a `change` that reaches no listener leaves the reader on the
  # upcoming list with the past option showing.
  it "paints the select and lands on the past list when it is chosen" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    create(:event,
      group: member.group,
      creator: member,
      name: "Spring concert",
      status: :confirmed,
      starts_at: 9.days.ago,
      ends_at: 9.days.ago + 2.hours)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(page).to paint "select"

    select "Past events", from: "Which events to show"

    expect(page).to have_current_path group_events_path(member.group, scope: "past")
    expect(page).to have_content "Spring concert"
    expect(page).to be_accessible
  end

  # Whether the page scrolls sideways, which is the one overflow a reader on a phone notices first.
  def overflowing?
    page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
  end

  # The card states its own copy, so an event here has a fixed name, place and hour rather than the
  # factory's random ones, and `status:` is named because the factory leaves it `unconfirmed`.
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
