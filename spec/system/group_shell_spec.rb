require "rails_helper"

# Only what a browser adds. Which controls a given reader sees - the pencil for an owner, the
# chevron for a reader with two groups, nothing at all for a signed-out visitor - is
# `spec/requests/groups_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md`
# it does not come back here.
#
# What no request spec can reach is whether the chrome paints, whether the two tab placements swap
# at the breakpoint, whether tapping a tab lands anywhere, whether the switcher opens as a modal,
# and whether an icon-only control has a name. Those are what this file is for.
#
# The paint targets are the group mark and the avatar rather than the header or the dock. Both of
# those carry `bg-base-100`, which in light is `oklch(100% 0 0)` - the same colour as the surface
# behind them - so a correctly painted header scores 1.0 and reads as painting nothing, exactly as
# `body` does. The mark is a `status status-primary` over that surface and the avatar
# `bg-base-300` over it, so
# both are things the matcher can actually judge; the text on the dock is measured against its own
# surface by `be_accessible`, which is the layer that reads text contrast.
RSpec.describe "The group shell", type: :system do
  it "paints the group mark and the avatar in light, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "header .status"
    expect(page).to paint ".avatar > span"
    expect(page).to be_accessible
  end

  it "paints the group mark and the avatar in dark, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "header .status"
    expect(page).to paint ".avatar > span"
    expect(page).to be_accessible
  end

  # Nothing below the browser can see which placement paints: both sets are in the markup at every
  # width, so a request spec finds two of each tab whatever the viewport.
  it "shows the tabs as the dock below the breakpoint" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(page).to have_css ".dock a[aria-label='Events']", visible: :visible
    expect(page).to have_css ".navbar a[aria-label='Events']", visible: :hidden
  end

  it "moves the tabs into the header above the breakpoint" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::DESKTOP

    visit group_path(member.group)

    expect(page).to have_css ".navbar a[aria-label='Events']", visible: :visible
    expect(page).to have_css ".dock a[aria-label='Events']", visible: :hidden
  end

  # A Turbo navigation, which is the one thing a request spec cannot assert: that the tab is a
  # control a person can use and that it arrives where it says.
  it "lands on the events list when the Events tab is used" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    within(".dock") { click_link "Events" }

    expect(page).to have_current_path group_events_path(member.group)
  end

  it "lands on the members list when the Members tab is used" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    within(".dock") { click_link "Members" }

    expect(page).to have_current_path group_members_path(member.group)
  end

  # Asserted on the rendered page rather than on the helper: the helper spec proves the mapping,
  # this proves the mapping reaches the markup.
  it "keeps the Events tab marked once inside that section" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_events_path(member.group)

    expect(page).to have_css ".dock a[aria-label='Events'][aria-current='page']"
  end

  it "opens the switcher and leads to the reader's other group" do
    member = create(:member, group: create(:group, name: "Riverside Choir"))
    other = create(:member, user: member.user, group: create(:group, name: "Harbour Band"))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    click_button "Switch group"

    # Wait for the sheet to finish sliding in before clicking into it. `[open]` is set the instant
    # `showModal()` runs and the dialog's opacity is already 1, but `.modal-top > .modal-box`
    # carries `translate: 0 -100%` and animates to `translate: 0` over about 300ms - so the row is
    # "visible" to Capybara while it is still off-screen, and a click at those coordinates hits
    # nothing or the row above.
    #
    # Measured over the DevTools Protocol rather than guessed: sampling every frame from
    # `showModal()`, the computed `translate` ran `0px -100%` -> `0px -82%` -> `0px -25%` -> `0px`,
    # and `elementFromPoint` at the second row's centre answered `none` for the first ~100ms.
    # Without this the example failed twice in twelve runs, always as "expected /groups/1 to equal
    # /groups/2" - the click landing on the current group, whose row navigates nowhere.
    expect(page).to have_css "#group-switcher .modal-box", style: { "translate" => "0px" }
    within("#group-switcher") { click_link "Harbour Band" }

    expect(page).to have_current_path group_path(other.group)
  end

  # The switcher is a `<dialog>` so that Escape, the backdrop and holding focus are the element's
  # own behaviour rather than script. That only holds if it is opened as a modal, and `showModal`
  # against `show` is invisible to every other assertion here.
  it "opens the switcher as a modal, so the element handles focus and Escape itself" do
    member = create(:member, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    click_button "Switch group"

    expect(page).to have_css "#group-switcher[open]"
    expect(page.evaluate_script("document.querySelector('#group-switcher').matches(':modal')")).to be true
  end

  # Whether the name fits is geometry, which nothing below the browser can measure: the markup is
  # the same string at every width, so a request spec sees a full name however little room it has.
  # Watched failing against `navbar-end`, which reserves half the row: 225px of box for 265px of
  # name.
  it "leaves the group's name the room the trailing controls are not using" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Community Choir"))
    create(:member, user: member.user, group: create(:group, name: "Harbour Band"))
    sign_in_as member.user
    resize_to ViewportHelper::DESKTOP

    visit group_path(member.group)

    expect(page).to have_text "Riverside Community Choir"
    expect(truncated?(".navbar span.truncate")).to be false
  end

  it "paints a pushed screen, whose back chevron leads up to the section" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit edit_group_path(member.group)
    expect(page).to paint ".avatar > span"
    expect(page).to be_accessible

    click_link "Back"

    expect(page).to have_current_path group_path(member.group)
  end
end
