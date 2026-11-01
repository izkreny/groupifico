require "rails_helper"

# Only what a browser adds. Who reaches the screen, who is listed and which ids `update` keeps are
# all `spec/requests/events/rosters_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left is the part no request spec can
# see: that the checkbox daisyUI draws is a box rather than a bare native tick, that the submit
# waits for a change and goes back to waiting once the change is undone, that a paused row without a checkbox still
# lines its name up with the rows that have one, and that submitting lands on the event.
RSpec.describe "Editing an event's list", type: :system do
  # `.checkbox` on an input is the whole claim: the class is in the markup either way, and only the
  # browser knows whether daisyUI drew a box or left the platform's own 13px tick.
  it "paints the tick as a daisyUI checkbox rather than a bare native one" do
    event, actor, = event_with_three_members
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)
    width, height = box_of("input.checkbox")

    expect(width).to be > 16
    expect(height).to be > 16
  end

  # An icon with no size class fills whatever holds it, which in a block button is the button's whole width.
  it "draws the submit's check at 20px" do
    event, actor, = event_with_three_members
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)

    expect(box_of("[data-list-target=submit] svg")).to eq [ 20, 20 ]
  end

  # No `paint` assertion on this screen, deliberately, and the alternatives were measured rather
  # than assumed. daisyUI's plain `.checkbox` sets `background-color` to `var(--input-color, #0000)`
  # in both states, so it composites to its own surface and scores exactly 1 whether it is ticked or
  # not; and a submit scores above 1 with `btn-primary`, with `btn-ghost` and with no `btn` class at
  # all, because the browser paints a button face by itself - watched passing in all three, which
  # makes it a check that cannot fail. The example above is what proves the checkbox is daisyUI's
  # rather than the platform's.
  #
  # The dimmed row is measured separately because axe cannot see it: an ancestor's `opacity` is not
  # composited into its colour-contrast rule, watched passing at `opacity-10`, which is unreadable.
  it "renders in light, with no accessibility violations" do
    event, actor, available, paused = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit edit_group_event_roster_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(available, :tick)

    expect(rendered_colour_scheme).to eq "light"
    expect(text_contrast("##{ActionView::RecordIdentifier.dom_id(paused)} .list-col-grow span")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
  end

  it "renders in dark, with no accessibility violations" do
    event, actor, available, paused = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit edit_group_event_roster_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(available, :tick)

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast("##{ActionView::RecordIdentifier.dom_id(paused)} .list-col-grow span")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
  end

  it "fits a phone without scrolling sideways" do
    event, actor, = event_with_three_members
    sign_in_as actor.user
    resize_to ViewportHelper::MOBILE

    visit edit_group_event_roster_path(event.group, event)

    expect(horizontal_overflow).to eq 0
  end

  # The paused row draws an empty placeholder where the others draw a control, and whether that
  # holds the column is geometry: a `span` carrying no text can collapse to nothing and slide the
  # name left, which no markup assertion sees.
  it "lines a paused member's name up with the names that have a checkbox" do
    event, actor, available, paused = event_with_three_members
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)

    expect(name_left_of(paused)).to eq name_left_of(available)
  end

  # Whether anything differs from what was drawn is nothing a server render can know, since the ticks never reach the server until the submit.
  it "waits for a new tick, and waits again once it is taken back" do
    event, actor, available, = event_with_three_members
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)
    expect(page).to have_button "Update the list", disabled: true

    check ActionView::RecordIdentifier.dom_id(available, :tick)
    expect(page).to have_button "Update the list", disabled: false

    uncheck ActionView::RecordIdentifier.dom_id(available, :tick)
    expect(page).to have_button "Update the list", disabled: true
  end

  it "takes an untick of a registered row as a change" do
    event, actor, = event_with_three_members
    create(:registration, event:, member: actor)
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)
    uncheck ActionView::RecordIdentifier.dom_id(actor, :tick)

    expect(page).to have_button "Update the list", disabled: false
  end

  # The landing is the browser's part; that the rows were written is the request spec's.
  it "reserves the ticked members and lands on the event" do
    event, actor, available, = event_with_three_members
    sign_in_as actor.user

    visit edit_group_event_roster_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(available, :tick)
    click_button "Update the list"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(page).to have_text "1 place reserved."
  end

  # A disabled box is exempt from WCAG's contrast rule and axe skips it, so whether the manager can read the line beside it is measured here.
  it "lets a manager read a registered row's caption in light" do
    actor, event, registered = managed_event_with_a_registration
    sign_in_as actor.user
    prefer_colour_scheme :light

    visit edit_group_event_roster_path(event.group, event)

    expect(page).to have_field ActionView::RecordIdentifier.dom_id(registered, :tick), checked: true, disabled: true
    expect(text_contrast("##{ActionView::RecordIdentifier.dom_id(registered)} label span:last-child")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
  end

  it "lets a manager read a registered row's caption in dark" do
    actor, event, registered = managed_event_with_a_registration
    sign_in_as actor.user
    prefer_colour_scheme :dark

    visit edit_group_event_roster_path(event.group, event)

    expect(page).to have_field ActionView::RecordIdentifier.dom_id(registered, :tick), checked: true, disabled: true
    expect(text_contrast("##{ActionView::RecordIdentifier.dom_id(registered)} label span:last-child")).to be >= ContrastHelper::WCAG_AA
    expect(page).to be_accessible
  end

  def managed_event_with_a_registration
    group = create(:group)
    actor = create(:member, :active, :with_all_attributes, group:)
    event = create(:event, group:, creator: actor, manager: actor)
    registered = create(:member, :active, :with_all_attributes, group:)
    create(:registration, event:, member: registered)

    [ actor, event, registered ]
  end

  # The one arrangement every example needs: an events administrator, a member who can be added
  # and one who is paused. Named profiles throughout, because every row draws a name.
  def event_with_three_members
    group = create(:group)
    actor = create(:member, :active, :events_administrator, :with_all_attributes, group:)
    event = create(:event, group:, creator: actor)

    [ event, actor,
      create(:member, :active, :with_all_attributes, group:),
      create(:member, :paused, :with_all_attributes, group:) ]
  end

  def box_of(selector)
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const r = document.querySelector("#{selector}").getBoundingClientRect();
        return [ Math.round(r.width), Math.round(r.height) ];
      })()
    JAVASCRIPT
  end

  def name_left_of(member)
    row = ActionView::RecordIdentifier.dom_id(member)

    page.evaluate_script(
      %(Math.round(document.querySelector("##{row} .list-col-grow").getBoundingClientRect().left))
    )
  end
end
