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
# plain `btn` whose base-200 face sits on the card's own base-200, so each scores exactly 1. A
# face-less control is seen by its glyph and its label, so that is what they assert instead: the
# planes against the 3:1 WCAG asks of an icon, Invite the rest against the 4.5:1 it asks of text.
# A soft primary face on the invited plane scored 1.01 in organic, which is a tint nobody can see, so
# the tint is the glyph's colour and is compared directly.
#
# `.card` rather than `.card.bg-base-200`, so the assertion reads the rendered colour rather than
# the class that asks for it, as `spec/system/events_list_spec.rb` explains.
RSpec.describe "The event detail", type: :system do
  it "paints the card and tints the invited row's paper plane, in light" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".card"
    expect(colour_of("Carla Duke is invited, no reply yet")).not_to eq colour_of("Invite Ben Cole")
  end

  it "shows the planes and Invite the rest by their glyphs and label in light" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(text_contrast("[aria-label='Carla Duke is invited, no reply yet']")).to be >= ContrastHelper::WCAG_NON_TEXT
    expect(text_contrast("[aria-label='Invite Ben Cole']")).to be >= ContrastHelper::WCAG_NON_TEXT
    expect(text_contrast(invite_the_rest(event))).to be >= ContrastHelper::WCAG_AA
  end

  it "shows the same three in dark" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast("[aria-label='Carla Duke is invited, no reply yet']")).to be >= ContrastHelper::WCAG_NON_TEXT
    expect(text_contrast("[aria-label='Invite Ben Cole']")).to be >= ContrastHelper::WCAG_NON_TEXT
    expect(text_contrast(invite_the_rest(event))).to be >= ContrastHelper::WCAG_AA
  end

  it "paints the card and tints the same plane in dark" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".card"
    expect(colour_of("Carla Duke is invited, no reply yet")).not_to eq colour_of("Invite Ben Cole")
  end

  # WHY: the glyph rather than the pill, so the surface measured against is the pill's own face.
  it "shows a row's lit pill by its glyph in light" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :light

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "light"
    expect(text_contrast("##{roster_row(owner)} .btn[aria-current='true'] svg")).to be >= ContrastHelper::WCAG_NON_TEXT
  end

  it "shows the same glyph in dark" do
    owner, event, = rostered_event
    sign_in_as owner.user
    prefer_colour_scheme :dark

    visit group_event_path(event.group, event)
    open_roster

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast("##{roster_row(owner)} .btn[aria-current='true'] svg")).to be >= ContrastHelper::WCAG_NON_TEXT
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

  # A plain member's rows are status icons alone, so this is the variant where the icon is the whole of what a row says, and an invited row's is drawn in the tally's info.
  it "paints a plain member's status icons, with no accessibility violations" do
    owner, event, ben = rostered_event
    member = create(:member, :active, group: owner.group)
    create(:registration, event:, member:, status: :invited)
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)
    open_roster

    expect(text_contrast("##{roster_row(member)} span[title]")).to be >= ContrastHelper::WCAG_NON_TEXT
    expect(page).to be_accessible
  end

  # The `<details>` is the whole mechanism: the rows are in the markup either way, and only the
  # browser decides whether they show.
  it "keeps the roster folded until Who’s coming is pressed" do
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

  # A word wider than the phone cannot wrap unless the heading lets it break, and then it pushes the Duplicate and Edit buttons beside it off the screen. Found by the styleguide drawing this Faker title.
  it "fits a long one-word name and its buttons on a phone" do
    owner = create(:member, :active, :owner)
    event = create(:event, group: owner.group, creator: owner, name: "Simpsoncalifragilisticexpiala(Annoyed Grunt)cious")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_event_path(event.group, event)

    expect(page).to have_css "[aria-label='Edit']"
    expect(horizontal_overflow).to eq 0
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

    # WHY: Ben's held place and the member with none are both asked.
    expect(page).to have_current_path group_event_path(event.group, event)
    expect(page).to have_text "2 members invited."
  end

  it "sets Who’s coming as a 16px heading" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)

    heading = find("summary > span", text: "Who’s coming").evaluate_script("[getComputedStyle(this).fontFamily, getComputedStyle(this).fontSize]")
    expect(heading).to match [ a_string_starting_with("Alegreya"), "16px" ]
  end

  # The theme's status colours, a tag's icon and number with no badge around them: yes in success, maybe in warning, no in error, no reply in info, and reserved in the page's ink.
  it "colours each tally tag in its status colour" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)

    inks = [ "yes", "maybe", "no", "no reply", "reserved" ].map { find("summary [aria-label='#{it}']").evaluate_script("getComputedStyle(this.parentElement).color") }
    expect(inks).to eq [ "rgb(29, 102, 38)", "rgb(103, 83, 1)", "rgb(151, 38, 34)", "rgb(24, 90, 137)", "rgb(32, 30, 29)" ]
  end

  # The page's ink at 60%: quieter than the words beside it, still clear of the 3:1 an icon needs.
  it "draws a fact's icon quieter than its words, yet at 3:1" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)

    fact = "##{ActionView::RecordIdentifier.dom_id(event)} > p:nth-of-type(2)"
    expect([ text_contrast("#{fact} svg"), text_contrast(fact) ]).to match [ be_between(3, 6), be > 10 ]
  end

  it "sets a fact's icon 6px from its words" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)

    gap = find("##{ActionView::RecordIdentifier.dom_id(event)} > p:nth-of-type(2) svg").evaluate_script(<<~JS)
      (svg => { const words = document.createRange(); words.selectNodeContents(svg.nextSibling); return words.getBoundingClientRect().left - svg.getBoundingClientRect().right })(this)
    JS
    expect(gap).to be_within(0.5).of(6)
  end

  it "spaces the heading from the first tag as the tags are spaced from each other" do
    owner, event, = rostered_event
    sign_in_as owner.user

    visit group_event_path(event.group, event)

    gaps = page.evaluate_script(<<~JS)
      (([ heading, yes, maybe ]) => [ yes.getBoundingClientRect().left - heading.getBoundingClientRect().right, maybe.getBoundingClientRect().left - yes.getBoundingClientRect().right ])([ document.querySelector("summary > span.font-heading"), ...[ "yes", "maybe" ].map(label => document.querySelector(`summary [aria-label='${label}']`).parentElement) ])
    JS
    expect(gaps.first).to be_within(0.5).of(gaps.last)
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

  def invite_the_rest(event)
    "form[action='#{group_event_invitation_path(event.group, event)}'] .btn"
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
