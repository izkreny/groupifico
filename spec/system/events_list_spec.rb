require "rails_helper"

# Only what a browser adds. Which rows a given reader sees, and what each carries, is `spec/requests/events_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md` it does not come back here. The card the group's next event gets is `spec/system/group_home_spec.rb`'s.
#
# What no request spec can reach is how a row is laid out, where pressing a row's answer lands, and the filter sheet: its count following the picks, Reset, the chips' ✕ and how its buttons stack.
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

  # WHY: #458 AC2. The + carries no text, so pressing it by name is what proves its accessible name reaches the browser.
  it "lands on the new event form from the +" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_events_path(member.group)
    click_link "New event"

    expect(page).to have_current_path new_group_event_path(member.group)
  end

  # The hero card's Duplicate and Edit are a 32px box around a 20px glyph, and the + is drawn as their sibling.
  it "draws the + as a 32px box around a 20px glyph" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_events_path(member.group)

    expect(find("a[aria-label='New event']").evaluate_script(<<~JS)).to eq [ 32, 32, 20 ]
      ((box, glyph) => [ box.width, box.height, glyph.width ])(this.getBoundingClientRect(), this.querySelector("svg").getBoundingClientRect())
    JS
    expect(page).to be_accessible
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

  # WHY: #460 AC2 and AC6. The funnel and every chip open the same sheet.
  it "opens the filter sheet from the funnel and from a chip" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_events_path(member.group)
    click_button "Filter events"
    expect(page).to have_css "dialog#event_filter_dialog[open]"
    within("#event_filter_dialog") { click_button "Close" }
    click_button "Upcoming"

    expect(page).to have_css "dialog#event_filter_dialog[open]"
  end

  # WHY: #460 AC12.
  it "passes axe with the filter sheet open, in organic and organic-dark" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    %i[ light dark ].each do |scheme|
      prefer_colour_scheme scheme
      visit group_events_path(member.group)
      click_button "Filter events"
      expect(page).to have_css("dialog#event_filter_dialog[open]").and be_accessible
    end
  end

  # WHY: #460 AC4. The count is fetched as the picks change, so only a browser sees it follow them.
  it "counts the events the sheet's picks would show as they change, then applies them" do
    member = create(:member, :owner)
    next_event_for(member)
    create(:event, :from_the_future, group: member.group, creator: member, name: "Advent concert", category: :gig, status: :confirmed)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Gig"

    expect(page).to have_button "Show 1 event"
    click_button "Show 1 event"
    expect(page).to have_text("Advent concert").and have_no_text("Tuesday rehearsal")
    expect(page).to have_button "Remove Gig"
  end

  # WHY: #460 AC5. A chip's ✕ applies everything else that was on, so only its own filter goes.
  it "removes one filter with its chip's ✕, leaving the others on" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Rehearsal", "Not answered"
    click_button "Show 0 events"
    click_button "Remove Rehearsal"

    expect(page).to have_button("Remove Not answered").and have_no_button("Remove Rehearsal")
  end

  # WHY: #460 AC8. Reset returns the sheet, not the list, to Upcoming with no filters, and the count follows.
  it "returns the sheet to Upcoming with no filters on Reset" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Past", "Gig"
    expect(page).to have_button "Show 0 events"
    click_button "Reset"

    expect(page).to have_button "Show 1 event"
    expect(find_by_id("event_filter_dialog").evaluate_script("[ ...this.querySelectorAll('input:checked') ].map(input => input.getAttribute('aria-label'))")).to eq %w[ Upcoming ]
  end

  # WHY: #460 AC9. What the sheet applies is kept per browser, so a later visit shows it.
  it "keeps the list applied for the next visit" do
    member = create(:member, :owner)
    past_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Past"
    click_button "Show 1 event"
    expect(page).to have_text "Spring concert"
    visit group_events_path(member.group)

    expect(page).to have_text("Spring concert").and have_button("Past")
  end

  # WHY: #460 AC7. Muted while nothing hides events from the list picked, primary once a filter does, and either way clearing 3:1 as an icon must.
  it "paints the funnel muted with no filter on and primary with one" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    muted = funnel_ink("text-icon-muted")
    pick_in_sheet "Rehearsal"
    click_button "Show 1 event"
    expect(page).to have_button "Remove Rehearsal"

    expect([ muted, funnel_ink("text-primary") ]).to eq [ [ true, true ], [ true, true ] ]
  end

  # WHY: #460 AC2. Side by side while both fit, Reset on the left; once they do not, "Show N events" goes first, full width, and Reset under it.
  it "stacks the sheet's buttons Show first once they no longer fit side by side" do
    member = create(:member, :owner)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)
    click_button "Filter events"
    reset, show = sheet_buttons
    resize_to [ 260, 700 ]
    narrow_reset, narrow_show = sheet_buttons

    expect([ reset.top == show.top && reset.left < show.left, narrow_show.top < narrow_reset.top ]).to eq [ true, true ]
  end

  def pick_in_sheet(*labels)
    click_button "Filter events"
    labels.each { find_by_id("event_filter_dialog").find("input[aria-label='#{it}']").click }
  end

  # Whether the funnel carries the named ink and still clears 3:1 as an icon.
  def funnel_ink(ink)
    funnel = "button[aria-label='Filter events']"
    [ find(funnel)[:class].include?(ink), text_contrast(funnel) >= ContrastHelper::WCAG_NON_TEXT ]
  end

  # Reset and "Show N events", the sheet's last two labelled buttons, each as its rounded top and left.
  def sheet_buttons
    find_by_id("event_filter_dialog").evaluate_script(<<~JS).map { Data.define(:top, :left).new(*it) }
      [ ...this.querySelectorAll("button.btn:not([aria-label])") ].slice(-2).map(button => button.getBoundingClientRect()).map(rect => [ Math.round(rect.top), Math.round(rect.left) ])
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

  # An upcoming event for the list to draw, with a fixed name, place and hour rather than the factory's random ones, and `status:` named because the factory leaves it `unconfirmed`.
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
