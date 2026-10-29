require "rails_helper"

# Only what a browser adds. Which controls a given reader sees - the pencil for an owner, the
# switcher for a reader with two groups, nothing at all for a signed-out visitor - is
# `spec/requests/groups_spec.rb`'s assertion, and per the duplication rule in `.agents/testing.md`
# it does not come back here.
#
# What no request spec can reach is whether the chrome paints, whether the two tab placements swap
# at the breakpoint, whether tapping a tab lands anywhere, whether the switcher opens and closes,
# and whether an icon-only control has a name. Those are what this file is for.
#
# The paint targets are the group mark and the avatar rather than the header or the dock. Both of
# those carry `bg-base-100`, which in light is `oklch(100% 0 0)` - the same colour as the surface
# behind them - so a correctly painted header scores 1.0 and reads as painting nothing, exactly as
# `body` does. The mark is a `status status-primary` over that surface and the avatar is
# `bg-base-300` over it, so both are things the matcher can actually judge; the text on the dock is
# measured against its own surface by `be_accessible`, which is the layer that reads text contrast.
RSpec.describe "The group shell", type: :system do
  it "paints the group mark and the avatar in light, with no accessibility violations" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "header .status"
    expect(page).to paint ".avatar > div"
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
    expect(page).to paint ".avatar > div"
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
    find("header summary").click
    within("#group-switcher") { click_link "Harbour Band" }

    expect(page).to have_current_path group_path(other.group)
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

  # The two chevrons swap on the details' own `[open]`, through `group-open:`, so the flip is CSS that only a browser resolves.
  it "points the switcher's chevron up while the menu is open, and down again once closed" do
    member = create(:member, group: create(:group, name: "Riverside Choir"))
    create(:member, user: member.user, group: create(:group, name: "Harbour Band"))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE
    shown = "[ ...document.querySelectorAll('header summary svg') ].map(icon => getComputedStyle(icon).display != 'none')"

    visit group_path(member.group)
    closed = page.evaluate_script(shown)
    find("header summary").click

    expect([ closed, page.evaluate_script(shown) ]).to eq [ [ true, false ], [ false, true ] ]
  end

  # The rows are ghost links whose hover and active fills would touch edge to edge, so they keep 8px between them, the app's gap between separate controls.
  it "keeps 8px between the switcher's rows" do
    member = create(:member, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)
    find("header summary").click

    expect(page.evaluate_script("(rows => Math.round(rows[1].getBoundingClientRect().top - rows[0].getBoundingClientRect().bottom))([ ...document.querySelectorAll('#group-switcher li a') ])")).to eq 8
  end

  # A `<details>` closes from its own summary alone, so the dropdown controller is what closes the menu on a click elsewhere.
  it "closes the switcher's menu on a click elsewhere" do
    member = create(:member, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)
    find("header summary").click
    find("main").click

    expect(page.evaluate_script("document.getElementById('group-switcher').open")).to be false
  end

  # And on Escape, handing focus back to the summary so the keyboard is where it was.
  it "closes the switcher's menu on Escape, focus back on its summary" do
    member = create(:member, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)
    find("header summary").click
    page.driver.browser.keyboard.type(:Escape)

    expect(page.evaluate_script("[ document.getElementById('group-switcher').open, document.activeElement.tagName ]")).to eq [ false, "SUMMARY" ]
  end

  # The header's flex slack has been wrong twice: once reserving half the row, once stretching the
  # name's box past its text so the controls sat at the far end of it. Neither is visible to
  # `truncated?`, whose `scrollWidth > clientWidth` is false either way, so this measures the gap
  # between the name and the chevron instead. `gap-2.5` is 10px.
  #
  # Watched failing against the pre-fix markup - `grow` on the name and no spacer - which answered
  # 79px at this width.
  it "keeps the name's controls beside it and the avatar at the row's end" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    create(:member, user: member.user, group: create(:group, name: "Harbour Band"))
    sign_in_as member.user
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(gap_after_text("header span.truncate", "header summary .btn")).to eq 10
    expect(gap_to_row_end("header a.avatar", "header")).to eq 0
  end

  it "paints a pushed screen, whose back chevron leads up to the section" do
    member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit edit_group_path(member.group)
    expect(page).to paint ".avatar > div"
    expect(page).to be_accessible

    click_link "Back"

    expect(page).to have_current_path group_path(member.group)
  end

  # `text-primary` is the colour the current tab, the back chevron and the icon buttons all paint,
  # so primary against `base-100` is the theme's one text-on-ground pair the shell depends on. axe
  # cannot see it: the tab is an icon with no text. Watched failing at 3.0:1 with light primary set
  # to the brand's #c67139, which daisyUI's stock light passes, and at 3.4:1 against stock dark.
  it "paints the current tab in primary at AA contrast in light" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(text_contrast(".dock a[aria-current='page']")).to be >= ContrastHelper::WCAG_AA
  end

  it "paints the current tab in primary at AA contrast in dark" do
    member = create(:member, group: create(:group))
    sign_in_as member.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(text_contrast(".dock a[aria-current='page']")).to be >= ContrastHelper::WCAG_AA
  end

  # The Tab goes to the page through Ferrum's keyboard rather than `send_keys`, which clicks its
  # element first: on `body` that starts the order from the dock, and on the switcher it opens the
  # menu. The style matcher retries, which is what waits out daisyUI's `border-color` transition:
  # read at once, the border is still on its way from the ghost button's transparent one. Watched
  # failing with the focus rule removed, where daisyUI's own 2px outline ring paints over a 1px
  # border. The inset line in the ground colour is what shows on a primary fill, where a primary
  # border cannot; on this ghost button it is invisible but computed all the same, and was watched
  # failing before its rule existed.
  it "thickens a focused button's border in primary rather than drawing a ring" do
    member = create(:member, :owner, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_path(member.group)
    page.driver.browser.keyboard.type(:Tab, :Tab)

    expect(page).to have_css "[aria-label='Edit group']:focus-visible",
      style: { "outline-style" => "none", "border-top-width" => "2px", "border-top-color" => "rgb(140, 73, 26)",
               "box-shadow" => "rgb(245, 234, 216) 0px 0px 0px 2px inset" }
  end

  # The switcher's summary is a name and a chevron rather than a button, so it shows focus as an outline in primary around both.
  it "outlines the focused switcher in primary" do
    member = create(:member, group: create(:group))
    create(:member, user: member.user, group: create(:group))
    sign_in_as member.user
    prefer_colour_scheme :light

    visit group_path(member.group)
    page.driver.browser.keyboard.type(:Tab)

    expect(page).to have_css "header summary:focus-visible", style: { "outline-style" => "solid", "outline-color" => "rgb(140, 73, 26)" }
  end

  # `document.fonts.load` rather than `document.fonts.check`, which answers true for a family no
  # `@font-face` declares, so it passes with the fonts gone. `load` resolves to the faces it
  # fetched: none without the rules, a rejection on a URL Propshaft did not digest, and the latin
  # face of each family here. Watched failing with the `@font-face` rules removed.
  it "loads Alegreya and Commissioner from the asset pipeline" do
    member = create(:member, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)

    expect(page.evaluate_async_script(<<~JAVASCRIPT)).to eq [ 1, 1 ]
      const done = arguments[arguments.length - 1];
      Promise.all([ document.fonts.load("600 16px Alegreya"), document.fonts.load("16px Commissioner") ])
        .then((faces) => done(faces.map((face) => face.length)), (error) => done(String(error)));
    JAVASCRIPT
  end

  it "draws Croatian and Serbian Cyrillic letters in both faces without falling back" do
    member = create(:member, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)

    expect(font_fallbacks([ "600 25px Alegreya", "16px Commissioner" ], "ČĆĐŠŽčćđšžЂЈЉЊЋЏђјљњћџ")).to eq []
  end
end
