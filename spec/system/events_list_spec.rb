require "rails_helper"

# Only what a browser adds. Which rows a given reader sees, and what each carries, is `spec/requests/events_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md` it does not come back here. The card the group's next event gets is `spec/system/group_home_spec.rb`'s.
#
# What no request spec can reach is how a row is laid out, whether the list menu paints, and where pressing a row's answer or a menu link lands.
RSpec.describe "The events list", type: :system do
  # A row puts its question in place, so answering it turns the question into the answer's icon at the row's end without leaving the list.
  it "answers a row in place, its question replaced by the answer's icon" do
    member = create(:member, :owner)
    next_event_for(member)
    event = create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
    create(:registration, event:, member:, status: :response_requested)
    sign_in_as member.user

    visit group_events_path(member.group)
    within("##{ActionView::RecordIdentifier.dom_id(event)}") { click_button "Maybe" }

    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(event)} > svg[aria-label='you said maybe']"
    expect(page).to have_current_path group_events_path(member.group)
    expect(page).to have_no_css "##{ActionView::RecordIdentifier.dom_id(event)} form"
  end

  # The list menu is this screen's title as well as its filter, so whether it paints as a surface of
  # its own is what tells a pill from one whose classes compiled to nothing.
  it "paints the list menu" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(page).to paint "#scope summary"
    expect(page).to be_accessible
  end

  # The menu's rows are links, so landing on the past list is a click on one, which only a browser follows through the opened `<details>`.
  it "lands on the past list from the list menu" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    past_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)
    find("#scope summary").click
    within("#scope") { click_link "Past events" }

    expect(page).to have_current_path group_events_path(member.group, scope: "past")
    expect(page).to have_text("Spring concert").and be_accessible
  end

  it "lands on the canceled list from the list menu" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    create(:event, :from_the_future, group: member.group, creator: member, name: "Autumn gig", status: :canceled)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)
    find("#scope summary").click
    within("#scope") { click_link "Canceled events" }

    expect(page).to have_current_path group_events_path(member.group, scope: "canceled")
    expect(page).to have_text("Autumn gig").and be_accessible
  end

  # A list row is a grid whose cells start at its top, so the status icon would sit level with the name rather than with the name and its meta line together.
  # A row that puts the question and carries the pencil, at phone width: the question has to start under the name, never in the pencil's column, which squeezed the name to a letter a line.
  it "puts a row's question under its name when the row also carries the pencil" do
    member = create(:member, :owner)
    next_event_for(member)
    registration = create(:registration, member:, status: :response_requested, event: create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    lefts = find_by_id(ActionView::RecordIdentifier.dom_id(registration.event)).evaluate_script(<<~JS)
      [ this.querySelector(":scope > div:not(.list-col-wrap)"), this.querySelector(":scope > .list-col-wrap") ].map(cell => Math.round(cell.getBoundingClientRect().left))
    JS
    expect(lefts.first).to eq lefts.last
  end

  it "centres a row's status icon on its name and meta line" do
    member = create(:member, :owner)
    event = past_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group, scope: "past")

    middles = find_by_id(ActionView::RecordIdentifier.dom_id(event)).evaluate_script(<<~JS)
      [ this.querySelector(":scope > svg"), this.querySelector(":scope > div") ].map(cell => cell.getBoundingClientRect()).map(rect => rect.top + rect.height / 2)
    JS
    expect(middles.first).to be_within(0.5).of(middles.last)
  end

  # The answer is the row's last cell, so it sits at the row's end in the colour the tally gives it, where it has to clear 3:1 on the page.
  it "draws the member's answer at the row's end, in its status colour" do
    member = create(:member, :owner)
    next_event_for(member)
    event = create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
    create(:registration, event:, member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)

    answer = "##{ActionView::RecordIdentifier.dom_id(event)} > svg[aria-label='you said yes']"
    placed = find(answer).evaluate_script("[ this.getBoundingClientRect().left > this.parentElement.querySelector(':scope > div').getBoundingClientRect().right, this.getAttribute('class').includes('text-success') ]")
    expect(placed).to eq [ true, true ]
    expect(text_contrast(answer)).to be >= ContrastHelper::WCAG_NON_TEXT
  end

  # The event's status at 24px, the size Heroicons draws its solid set for, and the reader's answer at 20px, the size every other registration status takes outside the tally; the status is a quiet fact, so it takes the muted icon ink, which still has to clear 3:1.
  it "draws a row's status at 24px and its answer at 20px, the event's status in the muted icon ink" do
    member = create(:member, :owner)
    next_event_for(member)
    event = create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
    create(:registration, event:, member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)

    status = "##{ActionView::RecordIdentifier.dom_id(event)} > svg:first-child"
    expect(find_by_id(ActionView::RecordIdentifier.dom_id(event)).evaluate_script("[ ...this.querySelectorAll(':scope > svg') ].map(icon => icon.getBoundingClientRect().width)")).to eq [ 24, 20 ]
    expect([ find(status)[:class].include?("text-icon-muted"), text_contrast(status) >= ContrastHelper::WCAG_NON_TEXT ]).to eq [ true, true ]
  end

  it "draws a row's pencil at 20px" do
    member = create(:member, :owner)
    next_event_for(member)
    event = create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
    sign_in_as member.user

    visit group_events_path(member.group)

    expect(find("##{ActionView::RecordIdentifier.dom_id(event)} a[aria-label^='Edit '] svg").evaluate_script("this.getBoundingClientRect().width")).to eq 20
  end

  # The roster's glyph gap, measured glyph to glyph rather than box to box, since the pencil's glyph sits inside a 32px button and the answer's stands bare.
  it "sets a row's pencil 20px from its answer" do
    member = create(:member, :owner)
    next_event_for(member)
    event = create(:event, group: member.group, creator: member, status: :confirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
    create(:registration, event:, member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)

    expect(find_by_id(ActionView::RecordIdentifier.dom_id(event)).evaluate_script(<<~JS)).to eq 20
      Math.round(this.querySelector("a[aria-label^='Edit '] svg").getBoundingClientRect().left - this.querySelector(":scope > svg[aria-label^='you said']").getBoundingClientRect().right)
    JS
  end

  # The other list needs something on it, and only its name is read: a concert that ended a week
  # ago is past by `ends_at` as well as by `starts_at`, which is the column `Event.past` reads.
  def past_event_for(member)
    create(:event,
      group: member.group,
      creator: member,
      name: "Spring concert",
      status: :concluded,
      starts_at: 9.days.ago,
      ends_at: 9.days.ago + 2.hours)
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
