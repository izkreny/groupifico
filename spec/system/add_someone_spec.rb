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
  # rather than the platform's.
  #
  # The dimmed row is measured separately because axe cannot see it: an ancestor's `opacity` is not
  # composited into its colour-contrast rule, watched passing at `opacity-10`, which is unreadable.
  it "renders in light, with no accessibility violations" do
    event, actor, invitable, paused = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)

    expect(rendered_colour_scheme).to eq "light"
    expect(dimmed_contrast(paused)).to be >= wcag_aa
    expect(page).to be_accessible
  end

  it "renders in dark, with no accessibility violations" do
    event, actor, invitable, paused = event_with_three_members
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)

    expect(rendered_colour_scheme).to eq "dark"
    expect(dimmed_contrast(paused)).to be >= wcag_aa
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

  # The landing is the browser's part; that the row was written is the request spec's.
  it "invites the ticked members and lands on the event" do
    event, actor, invitable, = event_with_three_members
    sign_in_as actor.user

    visit new_group_event_registration_path(event.group, event)
    check ActionView::RecordIdentifier.dom_id(invitable, :invite)
    click_button "Invite 1 person"

    expect(page).to have_current_path group_event_path(event.group, event)
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

  # The ratio WCAG 2.1 AA asks of normal text, which is what `spec/support/axe.rb` enforces
  # everywhere else on the screen.
  def wcag_aa = 4.5

  # The contrast the dimmed row actually reaches, which needs the row's `opacity` folded into the
  # text colour before it is compared with the surface - the step axe skips. Composited by filling
  # a canvas rather than by parsing, for the reason `spec/support/paint_matcher.rb` gives: this
  # palette resolves to `oklch(...)`, which no `rgb()`-shaped parser survives.
  def dimmed_contrast(member)
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const el = document.querySelector("##{ActionView::RecordIdentifier.dom_id(member)} .list-col-grow span");
        const canvas = document.createElement("canvas");
        canvas.width = canvas.height = 1;
        const ctx = canvas.getContext("2d", { willReadFrequently: true });
        const fill = (c) => { ctx.fillStyle = "rgba(0,0,0,0)"; ctx.fillStyle = c; ctx.fillRect(0, 0, 1, 1); };
        const pixel = () => Array.from(ctx.getImageData(0, 0, 1, 1).data);

        let alpha = 1;
        for (let n = el; n; n = n.parentElement) alpha *= parseFloat(getComputedStyle(n).opacity);

        let surface = "rgb(255, 255, 255)";
        for (let n = el.parentElement; n; n = n.parentElement) {
          const colour = getComputedStyle(n).backgroundColor;
          ctx.clearRect(0, 0, 1, 1); fill(colour);
          if (pixel()[3] === 255) { surface = colour; break; }
        }

        ctx.clearRect(0, 0, 1, 1); fill(surface); const beneath = pixel();
        ctx.clearRect(0, 0, 1, 1); fill(getComputedStyle(el).color); const ink = pixel();
        const blended = ink.slice(0, 3).map((v, i) => v * alpha + beneath[i] * (1 - alpha));

        const luminance = ([ r, g, b ]) => {
          const channel = (v) => { const s = v / 255; return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
          return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
        };

        const a = luminance(blended), b = luminance(beneath);
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
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
