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
# surface over the page's own `base-100`, and the pills carry theirs over the hero's.
# `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than
# the class that asks for it - with the class in the selector, an untinted hero fails as "does not
# exist" instead of as the ratio of 1 it actually paints.
RSpec.describe "The events list", type: :system do
  it "paints the hero card and the lit pill, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(page).to paint ".card"
    expect(page).to paint "[id^=next_up] .btn[aria-current='true']"
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
    expect(page).to paint "[id^=next_up] .btn[aria-current='true']"
    expect(page).to be_accessible
  end

  it "lands on the event with Who’s coming unfolded from the hero's responses" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    registration = create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)
    find("a", text: "Who’s coming?").click

    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(registration, :roster)}", visible: :visible
  end

  # The 12px the event screen keeps between Who’s coming? and its tags, and between the tags.
  it "spaces the hero's Who’s coming? link and its tags 12px apart" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)

    gaps = find("a", text: "Who’s coming?").evaluate_script(<<~JS)
      (label => { const items = [ label, ...[ "yes", "maybe" ].map(l => label.parentElement.querySelector(`[aria-label='${l}']`).parentElement) ]; return items.slice(1).map((el, i) => el.getBoundingClientRect().left - items[i].getBoundingClientRect().right) })(this)
    JS
    expect(gaps).to all(be_within(0.5).of(12))
  end

  # daisyUI grows every paragraph in a card body, so the question would stretch and push the buttons to the card's far edge.
  it "sets the hero's answer buttons 16px after the question, as on the event screen" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    page.driver.resize(1280, 900)

    visit group_events_path(member.group)

    gap = find("[id^=next_up] p", text: "Are you coming?").evaluate_script("(words => { words.selectNodeContents(this); return this.nextElementSibling.getBoundingClientRect().left - words.getBoundingClientRect().right })(document.createRange())")
    expect(gap).to be_within(0.5).of(16)
  end

  it "sets the hero's answer 14px under Who’s coming?, its facts 8px apart" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_events_path(member.group)

    gaps = find("[id^=next_up] .card-body").evaluate_script(<<~JS)
      (rows => rows.slice(-3).map((row, i, last) => i && Math.round(row.getBoundingClientRect().top - last[i - 1].getBoundingClientRect().bottom)).slice(1))([ ...this.children ].filter(row => row.getClientRects().length))
    JS
    expect(gaps).to eq [ 8, 14 ]
  end

  it "sets the hero's kicker as a secondary eyebrow" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)

    kicker = find("[id^=next_up] .card-body > p:first-child").evaluate_script(<<~JS)
      ((style, probe) => [ style.color === getComputedStyle(probe).color, style.textTransform, style.fontWeight, style.letterSpacing, probe.remove() ].slice(0, 4))(getComputedStyle(this), document.body.appendChild(Object.assign(document.createElement("span"), { className: "text-secondary" })))
    JS
    expect(kicker).to eq [ true, "uppercase", "600", "0.6px" ]
  end

  it "shows the lit pill by its label in light" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(label_contrast("[id^=next_up] .btn[aria-current='true']")).to be >= ContrastHelper::WCAG_AA
  end

  it "shows the same label in dark" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(label_contrast("[id^=next_up] .btn[aria-current='true']")).to be >= ContrastHelper::WCAG_AA
  end

  # The card is drawn for a phone and the pills are a `join` of three, so whether the row of them
  # fits beside the tags is geometry: the markup is identical at both widths and no request spec
  # can tell the two apart.
  it "fits the card inside the page at both widths" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :response_requested)
    sign_in_as member.user

    [ ViewportHelper::MOBILE, ViewportHelper::DESKTOP ].each do |viewport|
      resize_to viewport
      visit group_events_path(member.group)

      expect(overflowing?).to be false
    end
  end

  # An answer keeps the reader where they pressed it: the hero morphs in place, its question turned into the answer.
  it "writes the hero's answer and stays on the list" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    event = next_event_for(member)
    registration = create(:registration, event:, member:, status: :response_requested)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)
    click_button "Yes"

    expect(page).to have_css "[id^=next_up] p", text: "Are you coming?"
    expect(page).to have_current_path group_events_path(member.group)
    expect(registration.reload).to be_yes
  end

  # A row asks its question in place, so answering it turns the question into the answer's icon at the row's end without leaving the list.
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

  # Frame 4n. Which reader is offered it is `spec/requests/events_spec.rb`'s; that its label shows and
  # where pressing it lands is what a browser adds. No `paint` assertion, measured rather than
  # assumed: it is a plain `btn`, whose base-200 face sits on the hero's own base-200 and scores
  # exactly 1, as `Edit the list` does on the event's roster, so its label carries the claim instead.
  it "shows Ask everyone by its label, and lands back on the list" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :reserved)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(text_contrast("form[action$='/response_request'] .btn")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
    click_button "Ask everyone"

    expect(page).to have_current_path group_events_path(member.group)
    expect(page).to have_text "1 member asked."
  end

  it "shows Ask everyone by its label in dark" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :reserved)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast("form[action$='/response_request'] .btn")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
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

  # A list row is a grid whose cells start at its top, so the status icon would sit level with the name rather than with the name and its meta line together.
  # A row that asks and carries the pencil, at phone width: the question has to start under the name, never in the pencil's column, which squeezed the name to a letter a line.
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

  it "draws the hero's Duplicate and Edit at 20px, 20px apart" do
    member = create(:member, :owner)
    event = next_event_for(member)
    sign_in_as member.user

    visit group_events_path(member.group)

    expect(find_by_id(ActionView::RecordIdentifier.dom_id(event, :next_up)).evaluate_script(<<~JS)).to eq [ 20, 20, 20 ]
      ((duplicate, edit) => [ duplicate.width, edit.width, Math.round(edit.left - duplicate.right) ])(...["Duplicate", "Edit"].map(verb => this.querySelector(`a[aria-label^='${verb} '] svg`).getBoundingClientRect()))
    JS
  end

  # Whether the page scrolls sideways, which is the one overflow a reader on a phone notices first.
  def overflowing?
    page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
  end

  # The other list needs something on it, and only its name is read: a concert that ended a week
  # ago is past by `ends_at` as well as by `starts_at`, which is the column `Event.past` asks about.
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
