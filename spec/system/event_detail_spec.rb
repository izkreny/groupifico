require "rails_helper"

# Only what a browser adds. Which controls a given reader is offered, which rows the roster lists
# and in what order are `spec/requests/events_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here.
#
# What no request spec can reach: that the disclosure actually folds the roster away and unfolds it
# when the counts are pressed, that the card, a row's badge and its lit pill paint against the
# surface behind them in both themes, that an owner's row of controls fits a phone, and where the
# roster's pill and the pencil land.
#
# `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than
# the class that asks for it, as `spec/system/events_list_spec.rb` explains.
RSpec.describe "The event detail", type: :system do
  it "paints the card, a row's badge and its lit pill in light" do
    owner, event, ben = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".card"
    expect(page).to paint "##{roster_row(ben)} .badge"
    expect(page).to paint "##{roster_row(owner)} .join .btn-primary"
  end

  it "paints the same three in dark" do
    owner, event, ben = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(page).to paint "##{roster_row(ben)} .badge"
    expect(page).to paint "##{roster_row(owner)} .join .btn-primary"
  end

  it "has no accessibility violations with an owner's roster open, in light" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to be_accessible
  end

  it "has no accessibility violations with an owner's roster open, in dark" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  # A plain member's rows are badges alone, so this is the variant where the badge is the whole of
  # what a row says.
  it "paints a plain member's badges, with no accessibility violations" do
    owner, event, ben = rostered_event
    member = create(:member, :active, group: owner.group)
    create(:registration, event:, member:, status: :invited)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)
    open_roster

    expect(page).to paint "##{roster_row(ben)} .badge"
    expect(page).to be_accessible
  end

  # The `<details>` is the whole mechanism: the rows are in the markup either way, and only the
  # browser decides whether they show.
  it "keeps the roster folded until the counts are pressed" do
    owner, event, ben = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)
    expect(page).to have_css "summary", text: "Who’s coming"
    expect(page).to have_no_css "##{roster_row(ben)}", visible: :visible

    open_roster

    expect(page).to have_css "##{roster_row(ben)}", visible: :visible
  end

  # Three pills and a take-off beside a name is the widest row the screen draws, and whether it
  # fits is geometry the markup cannot state. Measured at the row's last control rather than off the
  # document, because the collapse clips what overflows it: a row 600px wide was watched leaving the
  # page's scroll width untouched while its take-off sat out of reach past the card's edge.
  it "fits an owner's widest row inside the card on a phone" do
    owner, event, ben = rostered_event
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)
    open_roster

    expect(gap_to_row_end("##{roster_row(ben)} [aria-label='Take Ben Cole off the list']", ".card-body")).to be >= 0
  end

  # That the row was written is `spec/requests/registrations_spec.rb`'s; the landing is the part a
  # browser adds.
  it "answers for somebody from their row and lands back on the event" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)
    open_roster
    click_button "Maybe for Ben Cole"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(page).to have_text "Registration was successfully updated."
  end

  it "lands on the edit form from the pencil" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)
    click_link "Edit"

    expect(page).to have_current_path edit_group_event_path(event.group, event)
  end

  def open_roster
    find("summary", text: "Who’s coming").click
  end

  def roster_row(member)
    ActionView::RecordIdentifier.dom_id(member.registrations.sole, :roster)
  end

  # An owner who has answered, and Ben, whose place is reserved: one row with a lit pill and one
  # with a badge, which is what the paint examples read. Named, because every row draws a name and
  # the pills are pressed by it.
  def rostered_event
    group = create(:group)
    owner = create(:member, :active, :owner, group:)
    ben = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Ben", last_name: "Cole"))
    event = create(:event, group:, creator: owner, status: :confirmed, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    create(:registration, event:, member: owner, status: :yes)
    create(:registration, event:, member: ben, status: :reserved)

    [ owner, event, ben ]
  end
end
