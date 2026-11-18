require "rails_helper"

# Only what a browser adds. Which rows a given reader sees, and what each carries, is `spec/requests/events_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md` it does not come back here. The card the group's next event gets is `spec/system/group_home_spec.rb`'s.
#
# What no request spec can reach is how a row is laid out, where pressing a row's answer lands, and the filter sheet: its count following the picks, Clear all, the chips' ✕ and how its buttons stack.
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

  # WHY: #460 AC2 and AC6. The funnel and every filter's chip open the same sheet.
  it "opens the filter sheet from the funnel and from a chip" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_events_path(member.group, category: %w[ gig ])
    click_button "Filter events"
    expect(page).to have_css "dialog#event_filter_dialog[open]"
    within("#event_filter_dialog") { click_button "Close" }
    click_button "Gig"

    expect(page).to have_css "dialog#event_filter_dialog[open]"
  end

  # WHY: #460 AC12. The tabs and the chips paint differently in each theme, and an inactive tab is where daisyUI's own dimming fell short of 4.5:1.
  it "passes axe on the list with its tabs and chips, in organic" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user
    prefer_colour_scheme :light

    visit group_events_path(member.group, category: %w[ rehearsal ])

    expect(page).to have_link("Clear all").and be_accessible
  end

  it "passes axe on the list with its tabs and chips, in organic-dark" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user
    prefer_colour_scheme :dark

    visit group_events_path(member.group, category: %w[ rehearsal ])

    expect(page).to have_link("Clear all").and be_accessible
  end

  # WHY: #460 AC12. The sheet is only in the accessibility tree while it is open, which only a browser can make it, and its picks paint differently in each theme.
  it "passes axe with the filter sheet open, in organic" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE
    prefer_colour_scheme :light

    visit group_events_path(member.group)
    click_button "Filter events"

    expect(page).to have_css("dialog#event_filter_dialog[open]").and be_accessible
  end

  it "passes axe with the filter sheet open, in organic-dark" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE
    prefer_colour_scheme :dark

    visit group_events_path(member.group)
    click_button "Filter events"

    expect(page).to have_css("dialog#event_filter_dialog[open]").and be_accessible
  end

  # WHY: #460 AC4. Answering a row in place redraws the count without reconnecting the sheet, so the count Back restores has to be that one, not the count the page first loaded with.
  it "keeps a count redrawn by answering in place when the list is left and come back to" do
    member = create(:member, :owner)
    create(:registration, member:, status: :response_requested, event: next_event_for(member))
    sign_in_as member.user

    visit group_events_path(member.group, answer: %w[ not_answered ])
    click_button "Maybe"
    expect(page).to have_text "No events match these filters."
    click_link "New event"
    expect(page).to have_current_path new_group_event_path(member.group)
    go_back

    expect(page).to have_button "Show 0 events", visible: :all
  end

  # WHY: #460 AC9. Back restores the list from Turbo's snapshot without a request, so picks left unapplied would come back in the sheet, disagreeing with the list and the chips under it.
  it "drops the sheet's unapplied picks when the list is left and come back to" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Gig"
    expect(page).to have_button "Show 0 events"
    leave_for_a_new_event_and_come_back(member.group)
    click_button "Filter events"

    expect(page).to have_button("Show 1 event").and have_no_css("#event_filter_dialog input:checked")
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
    expect(page).to have_link "Remove Gig"
  end

  # WHY: #460 AC5. A chip's ✕ links the list with everything else still on, so only its own filter goes.
  it "removes one filter with its chip's ✕, leaving the others on" do
    member = create(:member, :owner)
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    pick_in_sheet "Rehearsal", "Not answered"
    click_button "Show 0 events"
    click_link "Remove Rehearsal"

    expect(page).to have_link("Remove Not answered").and have_no_link("Remove Rehearsal")
  end

  # WHY: #460 AC8. Clear all unticks the sheet's picks, not the list's, and the count follows; applying it leaves the tab as it is.
  it "clears every pick in the sheet on Clear all, keeping the tab" do
    member = create(:member, :owner)
    past_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group, scope: "past")
    pick_in_sheet "Rehearsal"
    expect(page).to have_button "Show 0 events"
    click_button "Clear all"
    expect(find_by_id("event_filter_dialog").evaluate_script("this.querySelectorAll('input:checked').length")).to eq 0
    click_button "Show 1 event"

    expect(page).to have_current_path(group_events_path(member.group, scope: "past")).and have_text("Spring concert")
  end

  # WHY: #460 AC9. The tab and the sheet's picks travel in the URL, so picks applied on a tab stay on it; that a plain visit then opens on Upcoming with nothing on is the request spec's.
  it "applies the sheet's picks through the URL, on the open tab" do
    member = create(:member, :owner)
    past_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)
    click_link "Past"
    pick_in_sheet "Other"
    click_button "Show 1 event"

    expect(page).to have_current_path("#{group_events_path(member.group)}?scope=past&category%5B%5D=other").and have_text("Spring concert")
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
    expect(page).to have_link "Remove Rehearsal"

    expect([ muted, funnel_ink("text-primary") ]).to eq [ [ true, true ], [ true, true ] ]
  end

  # WHY: #460 AC4. A count whose response is the sign-in page has no frame to swap in, so the sheet follows it rather than replacing "Show N events" with "Content missing".
  it "follows a lapsed session to sign-in from the sheet's count" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_events_path(member.group)
    click_button "Filter events"
    member.user.sessions.destroy_all
    find_by_id("event_filter_dialog").find("input[aria-label='Gig']").click

    expect(page).to have_current_path new_session_path, ignore_query: true
  end

  # WHY: #460 AC2. Side by side while both fit, Clear all on the left; once they do not, "Show N events" goes first, full width, and Clear all under it.
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

  # A Turbo visit away and Back, so the list comes back from Turbo's snapshot rather than from a request.
  def leave_for_a_new_event_and_come_back(group)
    within("#event_filter_dialog") { click_button "Close" }
    click_link "New event"
    expect(page).to have_current_path new_group_event_path(group)
    go_back
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

  # Clear all and "Show N events", the sheet's last two labelled buttons, each as its rounded top and left.
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
