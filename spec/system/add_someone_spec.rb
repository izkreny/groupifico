require "rails_helper"

# Only what a browser adds. Who reaches the screen, who is listed and which ids `create` keeps are
# all `spec/requests/registrations_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left is the part no request spec can
# see: that the checkbox daisyUI draws is a box rather than a bare native tick, that the submit
# counts what is ticked and refuses to send nothing, that a paused row without a checkbox still
# lines its name up with the rows that have one, and that submitting lands on the event.
RSpec.describe "Adding someone to an event", type: :system do
  # `.checkbox` on an input is the whole claim: the class is in the markup either way, and only the
  # browser knows whether daisyUI drew a box or left the platform's own 13px tick.
  it "paints the tick as a daisyUI checkbox rather than a bare native one" do
    event, actor, = event_with_three_members
    sign_in_as actor.user

    visit new_group_event_registration_path(event.group, event)
    width, height = box_of("input.checkbox")

    expect(width).to be > 16
    expect(height).to be > 16
  end

  # No `paint` assertion on this screen, deliberately, and the alternatives were measured rather
  # than assumed. daisyUI's plain `.checkbox` sets `background-color` to `var(--input-color, #0000)`
  # in both states, so it composites to its own surface and scores exactly 1 whether it is ticked or
  # not; and a submit scores above 1 with `btn-primary`, with `btn-ghost` and with no `btn` class at
  # all, because the browser paints a button face by itself - watched passing in all three, which
  # makes it a check that cannot fail. The example above is what proves the checkbox is daisyUI's
  # rather than the platform's, and `be_accessible` measures every contrast on the screen.
  it "renders in light, with no accessibility violations" do
    event, actor, invitable, = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to be_accessible
  end

  it "renders in dark, with no accessibility violations" do
    event, actor, invitable, = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to be_accessible
  end

  it "fits a phone without scrolling sideways" do
    event, actor, = event_with_three_members
    sign_in_as actor.user
    resize_to ViewportHelper::MOBILE

    visit new_group_event_registration_path(event.group, event)

    expect(horizontal_overflow).to eq 0
  end

  # The paused row draws an empty placeholder where the others draw a control, and whether that
  # holds the column is geometry: a `span` carrying no text can collapse to nothing and slide the
  # name left, which no markup assertion sees.
  it "lines a paused member's name up with the names that have a checkbox" do
    event, actor, invitable, paused = event_with_three_members
    sign_in_as actor.user

    visit new_group_event_registration_path(event.group, event)

    expect(name_left_of(paused)).to eq name_left_of(invitable)
  end

  # The count is the frame's own wording and nothing server-rendered can know it, since the ticks
  # never reach the server until the submit.
  it "counts the ticked members into the submit and refuses to send none" do
    event, actor, invitable, = event_with_three_members
    sign_in_as actor.user

    visit new_group_event_registration_path(event.group, event)
    expect(page).to have_button "Invite", disabled: true

    check ActionView::RecordIdentifier.dom_id(actor, :invite)
    expect(page).to have_button "Invite 1 person"

    check ActionView::RecordIdentifier.dom_id(invitable, :invite)
    expect(page).to have_button "Invite 2 people"
  end

  it "invites the ticked members and lands on the event" do
    event, actor, invitable, = event_with_three_members
    sign_in_as actor.user

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)
    click_button "Invite 1 person"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(event.reload.attendees).to contain_exactly invitable
  end

  # The one arrangement every example needs: an events administrator, a member who can be invited
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
