require "rails_helper"

# Only what a browser adds. Which of the two states a reader gets, and which controls each offers
# whom, is `spec/requests/groups_spec.rb`'s assertion, and per the duplication rule in
# `.agents/testing.md` none of it comes back here. The chrome above the screen - the mark, the
# switcher, the tabs - is `spec/system/group_shell_spec.rb`'s and is not repeated either.
#
# What no request spec can reach: whether either state paints at all, whether the card's lit pill is distinguishable from its neighbours, how the card is spaced and whether it fits, and where pressing one of its controls or "See all events" lands.
#
# The paint targets are surfaces the matcher can judge: the hero is a `base-200` card over the page's own `base-100`, the pills carry theirs over the card's, and the first-run screen's own surfaces are the button and the note beneath it. `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than the class that requests it - with the class in the selector, an untinted card fails as "does not exist" instead of as the ratio of 1 it actually paints. `body` and anything carrying `bg-base-100` would composite to 1.0 in light and read as painting nothing.
RSpec.describe "The group home", type: :system do
  it "paints the hero and the lit pill in light, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".card"
    expect(page).to paint "[id^=next_up] .btn[aria-current='true']"
    expect(page).to be_accessible
  end

  it "paints the hero and the lit pill in dark, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(page).to paint "[id^=next_up] .btn[aria-current='true']"
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

  it "lands on the event with Who’s coming unfolded from the card's responses" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    registration = create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_path(member.group)
    find("a", text: "Who’s coming?").click

    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(registration, :roster)}", visible: :visible
  end

  # The 12px the event screen keeps between Who’s coming? and its tags, and between the tags.
  it "spaces the card's Who’s coming? link and its tags 12px apart" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_path(member.group)

    gaps = find("a", text: "Who’s coming?").evaluate_script(<<~JS)
      (label => { const items = [ label, ...[ "yes", "maybe" ].map(l => label.parentElement.querySelector(`[aria-label='${l}']`).parentElement) ]; return items.slice(1).map((el, i) => el.getBoundingClientRect().left - items[i].getBoundingClientRect().right) })(this)
    JS
    expect(gaps).to all(be_within(0.5).of(12))
  end

  # daisyUI grows every paragraph in a card body, so the question would stretch and push the buttons to the card's far edge.
  it "sets the card's answer buttons 16px after the question, as on the event screen" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    page.driver.resize(1280, 900)

    visit group_path(member.group)

    gap = find("[id^=next_up] p", text: "Are you coming?").evaluate_script("(words => { words.selectNodeContents(this); return this.nextElementSibling.getBoundingClientRect().left - words.getBoundingClientRect().right })(document.createRange())")
    expect(gap).to be_within(0.5).of(16)
  end

  it "sets the card's answer 14px under Who’s coming?, its facts 8px apart" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user

    visit group_path(member.group)

    gaps = find("[id^=next_up] .card-body").evaluate_script(<<~JS)
      (rows => rows.slice(-3).map((row, i, last) => i && Math.round(row.getBoundingClientRect().top - last[i - 1].getBoundingClientRect().bottom)).slice(1))([ ...this.children ].filter(row => row.getClientRects().length))
    JS
    expect(gaps).to eq [ 8, 14 ]
  end

  it "sets the card's kicker as a secondary eyebrow" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    next_event_for(member)
    sign_in_as member.user

    visit group_path(member.group)

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

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(label_contrast("[id^=next_up] .btn[aria-current='true']")).to be >= ContrastHelper::WCAG_AA
  end

  it "shows the same label in dark" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :yes)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

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
      visit group_path(member.group)

      expect(overflowing?).to be false
    end
  end

  # An answer keeps the reader where they pressed it: the card morphs in place, its question turned into the answer.
  it "writes the card's answer and stays on the home" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    event = next_event_for(member)
    registration = create(:registration, event:, member:, status: :response_requested)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    click_button "Yes"

    expect(page).to have_css "[id^=next_up] p", text: "Are you coming?"
    expect(page).to have_current_path group_path(member.group)
    expect(registration.reload).to be_yes
  end

  # Frame 4n. Which reader is offered it is `spec/requests/groups_spec.rb`'s; that its label shows and where pressing it lands is what a browser adds. No `paint` assertion, measured rather than assumed: it is a plain `btn`, whose base-200 face sits on the card's own base-200 and scores exactly 1, as Request the rest does on the event's roster, so its label carries the claim instead.
  it "shows Request responses by its label, and lands back on the home" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :reserved)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(text_contrast("form[action$='/response_request'] .btn")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
    click_button "Request responses"

    expect(page).to have_current_path group_path(member.group)
    expect(page).to have_text "1 response requested."
  end

  it "shows Request responses by its label in dark" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:registration, event: next_event_for(member), member:, status: :reserved)
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast("form[action$='/response_request'] .btn")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
  end

  it "draws the card's Duplicate and Edit at 20px, 20px apart" do
    member = create(:member, :owner)
    event = next_event_for(member)
    sign_in_as member.user

    visit group_path(member.group)

    expect(find_by_id(ActionView::RecordIdentifier.dom_id(event, :next_up)).evaluate_script(<<~JS)).to eq [ 20, 20, 20 ]
      ((duplicate, edit) => [ duplicate.width, edit.width, Math.round(edit.left - duplicate.right) ])(...["Duplicate", "Edit"].map(verb => this.querySelector(`a[aria-label^='${verb} '] svg`).getBoundingClientRect()))
    JS
  end

  # Whether the page scrolls sideways, which is the one overflow a reader on a phone notices first.
  def overflowing?
    page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
  end

  # The card states its own copy, so an event here has a fixed name, place and hour rather than the factory's random ones: a confirmed one, upcoming, so `Group#featured_event` answers it rather than whatever the factory rolled.
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
