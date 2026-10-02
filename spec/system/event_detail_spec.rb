require "rails_helper"

# Only what a browser adds. Which controls a given reader is offered, which rows the roster lists
# and in what order are `spec/requests/events_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here.
#
# What no request spec can reach: that the disclosure actually folds the roster away and unfolds it
# when the counts are pressed, that the card and a row's lit pill paint against the surface behind
# them in both themes, that an invited row's paper plane is tinted where a reserved row's is not,
# that an owner's row of controls fits a phone, and where the roster's pill, its paper plane, Invite
# the rest and the pencil land.
#
# Neither paper plane nor Invite the rest takes a `paint` assertion, and both were measured rather
# than assumed: the planes are ghost buttons, like the take-off beside them, and Invite the rest is a
# plain `btn` whose base-200 face sits on the card's own base-200, so each scores exactly 1. A soft
# primary face on the invited plane scored 1.01 in one theme, which is a tint nobody can see, so the
# tint is the glyph's colour and is compared directly.
#
# `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than
# the class that asks for it, as `spec/system/events_list_spec.rb` explains.
RSpec.describe "The event detail", type: :system do
  it "paints the card and a row's lit pill, and tints the invited row's paper plane, in light" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".card"
    expect(page).to paint "##{roster_row(owner)} .join .btn-primary"
    expect(colour_of("Carla Duke is invited, no reply yet")).not_to eq colour_of("Invite Ben Cole")
  end

  it "paints the same two and tints the same plane in dark" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(page).to paint "##{roster_row(owner)} .join .btn-primary"
    expect(colour_of("Carla Duke is invited, no reply yet")).not_to eq colour_of("Invite Ben Cole")
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

  # That the place was asked is `spec/requests/registrations/invitations_spec.rb`'s; the landing is
  # what a browser adds.
  it "asks a reserved member from their row's paper plane and lands back on the event" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)
    open_roster
    click_button "Invite Ben Cole"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(page).to have_text "Ben Cole invited."
  end

  it "invites the rest and lands back on the event" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)
    open_roster
    click_button "Invite the rest"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(page).to have_text "1 member invited."
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

  # The rendered colour the glyph inherits, read off the button that names it.
  def colour_of(label)
    page.evaluate_script(%(getComputedStyle(document.querySelector("[aria-label='#{label}'] svg")).color))
  end

  def roster_row(member)
    ActionView::RecordIdentifier.dom_id(member.registrations.sole, :roster)
  end

  # An owner who has answered, Ben, whose place is reserved, Carla, who is invited, and an active
  # member nobody has asked: a row with a lit pill, a plain member's badge on Ben's row, the tinted
  # paper plane on Carla's, and Invite the rest for the member missing. Named, because every row
  # draws a name and the pills and planes are pressed by it.
  def rostered_event
    group = create(:group)
    owner = create(:member, :active, :owner, group:)
    ben = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Ben", last_name: "Cole"))
    carla = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Carla", last_name: "Duke"))
    create(:member, :active, group:)
    event = create(:event, group:, creator: owner, status: :confirmed, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    create(:registration, event:, member: owner, status: :yes)
    create(:registration, event:, member: ben, status: :reserved)
    create(:registration, event:, member: carla, status: :invited)

    [ owner, event, ben ]
  end
end
