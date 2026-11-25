require "rails_helper"

# Only what a browser adds. Who sees the "not signed in yet" mark, the +, the pencil and which
# tabs and filters, which members are listed and in what order, are `spec/requests/members_spec.rb`'s
# assertions. What is left: that the tags and the buttons paint, that a dimmed row stays readable,
# which axe-core measures here since the dim is a theme colour with its own alpha, and that the
# name and the pencil land where they say.
RSpec.describe "The members list", type: :system do
  it "paints the mark on a member who has never signed in, with no accessibility violations" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    added = create(:member, group: actor.group, user: create(:user, :with_full_profile, first_signed_in_at: nil))
    sign_in_as actor.user

    visit group_members_path(actor.group)

    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(added, :row)} .badge"
    expect(page).to be_accessible
  end

  # WHY: N7 in the browser, the plane on a dimmed row opening its dialog rather than posting, and the dialog itself undimmed.
  it "opens the Send again dialog from a pending row's plane, with no accessibility violations" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    create(:member, :pending, group: actor.group, user: create(:user, first_name: "Casey", last_name: "Moreno"))
    sign_in_as actor.user

    visit group_members_path(actor.group, status: "pending")
    click_button "Resend invitation to Casey Moreno"

    expect(page).to have_css "dialog[open]", text: "Send Casey Moreno the invitation again?"
    expect(page.evaluate_script("getComputedStyle(document.querySelector('dialog[open] h3')).color")).not_to match %r{/ 0\.\d+\)}
    expect(page).to be_accessible
  end

  it "resends an invitation on Send again, landing back on the Pending tab" do
    actor = create(:member, :active, :members_administrator, :with_all_attributes)
    create(:member, :pending, group: actor.group, user: create(:user, first_name: "Casey", last_name: "Moreno"))
    sign_in_as actor.user

    visit group_members_path(actor.group, status: "pending")
    click_button "Resend invitation to Casey Moreno"
    within("dialog[open]") { click_button "Send again" }

    expect(page).to have_text "Invitation sent again."
    expect(page).to have_current_path group_members_path(actor.group, status: "pending")
  end

  # WHY: at phone width a text Resend button squeezed the name column until each name broke letter by letter, so the name has to stay on one line beside the row's controls.
  it "keeps a pending member's name on one line beside its controls at phone width, with no accessibility violations" do
    actor   = create(:member, :active, :members_administrator, :with_all_attributes)
    invitee = create(:member, :pending, group: actor.group, user: create(:user, first_name: "Casey", last_name: "Moreno"))
    sign_in_as actor.user
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group, status: "pending")

    expect(page.evaluate_script(<<~JS)).to eq 1
      (() => { const range = document.createRange(); range.selectNodeContents(document.querySelector("##{ActionView::RecordIdentifier.dom_id(invitee)} a")); return range.getClientRects().length })()
    JS
    expect(page).to be_accessible
  end

  it "paints the roster in light, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :owner, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group, status: "paused")

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(paused, :row)} .badge"
    expect(page).to be_accessible
  end

  it "paints the roster in dark, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :owner, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group, status: "paused")

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(paused, :row)} .badge"
    expect(page).to be_accessible
  end

  it "lands on a member's screen from their name" do
    actor  = create(:member, :active, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)
    click_link target.full_name

    expect(page).to have_current_path group_member_path(actor.group, target)
    expect(page).to have_text target.email
  end

  it "lands on a member's edit form from the pencil" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)
    click_link "Edit #{target.full_name}"

    expect(page).to have_current_path edit_group_member_path(actor.group, target)
    expect(page).to have_button "Save member"
  end

  # WHY: #508 AC1. The avatar is no control, so pressing it is pressing the row. Pressed by its coordinates, because Cuprite refuses to click an element something else covers, and being covered by the name's link is the point.
  it "lands on a member's screen from anywhere on their row" do
    actor  = create(:member, :active, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)
    x, y = find("##{ActionView::RecordIdentifier.dom_id(target, :row)} .avatar").evaluate_script("(box => [ box.left + box.width / 2, box.top + box.height / 2 ])(this.getBoundingClientRect())")
    page.driver.browser.mouse.click(x:, y:)

    expect(page).to have_current_path group_member_path(actor.group, target)
  end

  # WHY: #508 AC3. A press lands on whatever is topmost under it, so every control on the row has to be the topmost element at its own centre rather than the name's overlay.
  it "keeps every control on a row above the link to its member" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, group: actor.group, user: create(:user, first_name: "Ana", last_name: "Horvat"))
    sign_in_as actor.user
    page.current_window.resize_to(1280, 900)

    visit group_members_path(actor.group)

    topmost = find_by_id(ActionView::RecordIdentifier.dom_id(target, :row)).evaluate_script(<<~JS)
      [...this.querySelectorAll("a, button")].slice(1).map(control => (box => [ control.getAttribute("aria-label"), control.contains(document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)) ])(control.getBoundingClientRect()))
    JS
    expect(topmost).to eq [ [ "Call Ana Horvat", true ], [ "Email Ana Horvat", true ], [ "Edit Ana Horvat", true ] ]
  end

  # WHY: #368; daisyUI's `list-row` breaks a long word, so a row wraps a long name and keeps Call, Email and the pencil inside it.
  it "wraps a long one-word name inside its row on a phone" do
    owner = create(:member, :active, :owner)
    member = create(:member, :active, group: owner.group, user: create(:user, first_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", last_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious"))
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_members_path(owner.group)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(member, :row)} a[aria-label^='Edit ']", "##{ActionView::RecordIdentifier.dom_id(member, :row)}")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word name inside its row on a phone" do
    owner = create(:member, :active, :owner)
    member = create(:member, :active, group: owner.group, user: create(:user, first_name: "Maximilian Bartholomew Featherstonehaugh", last_name: "Montgomery Worthington Smythe"))
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_members_path(owner.group)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(member, :row)} a[aria-label^='Edit ']", "##{ActionView::RecordIdentifier.dom_id(member, :row)}")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "draws a row's icons at 20px, 20px apart" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)

    expect(find_by_id(ActionView::RecordIdentifier.dom_id(target, :row)).evaluate_script(<<~JS)).to eq [ 20, 20, 20, 20 ]
      ((call, email) => [ call.width, email.width, Math.round(email.left - call.right), email.height ])(...["Call", "Email"].map(verb => this.querySelector(`a[aria-label^='${verb} '] svg`).getBoundingClientRect()))
    JS
  end

  # WHY: daisyUI's `btn-sm` computes the same 32px at the shipped token, so only a changed token can tell the button's box follows it.
  it "sizes an icon button's box from the control token" do
    actor  = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :with_all_attributes, group: actor.group)
    sign_in_as actor.user

    visit group_members_path(actor.group)

    expect(find("##{ActionView::RecordIdentifier.dom_id(target, :row)} a[aria-label^='Call ']").evaluate_script(<<~JS)).to eq [ 40, 40 ]
      (() => { this.style.setProperty("--spacing-control", "2.5rem"); const box = this.getBoundingClientRect(); return [ box.width, box.height ] })()
    JS
  end

  # WHY: the invitation and the join link live in the Add member dialog the owner opens from the + on this page. Which state draws which control, and for whom, is `spec/requests/members_spec.rb`'s; what is left is where focus lands on opening, that an invitation lands where the member form's does, that the dialog stays open through each action, that Copy puts the link on the clipboard, and that Regenerate and Delete ask first.
  context "with the Add member dialog" do
    def open_add_member
      click_on "Add member"
      expect(page).to have_css "dialog#add_member_dialog[open]"
    end

    def join_link_url = find_by_id("join_link_url").value

    # WHY: #445 AC1, walked in the browser, since only the browser can tell that Copy wrote the clipboard, and that creating the link leaves its dialog open to copy from.
    it "creates and copies the link" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: reading the clipboard back needs its permission, granted in the browser context Cuprite opened for this session rather than Chrome's default one, where a grant reaches no page here.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-read" }, setting: "granted")
      open_add_member
      click_on "Create new join link"
      click_on "Copy link"

      expect(page).to have_css "dialog#add_member_dialog[open]"
      expect(page).to have_css "#add_member_dialog button.btn-secondary", exact_text: "Link copied"
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq join_link_url
    end

    # WHY: #506 AC3, walked in the browser, since the sheet's form is the member form's invitation: it lands where that one does and names who was invited.
    it "invites a person from the dialog and says who" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      fill_in "invite_by_email_email", with: "new.person@example.com"
      click_on "Send invitation"

      expect(page).to have_text "Invitation sent to new.person@example.com."
      expect(page).to have_current_path group_member_path(member.group, member.group.members.pending.sole)
    end

    # WHY: a refused address lands on the invite page as the member form's does, and that page has to be usable, with no dialog left modal over it.
    it "shows a refused address on the invite page, with nothing left modal" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      fill_in "invite_by_email_email", with: member.user.email
      click_on "Send invitation"

      expect(page).to have_text "Email already belongs to a member of this group"
      # WHY: `:modal` rather than `dialog[open]`, since a dialog a morph left in the top layer has lost `open` and still blocks the page.
      expect(page).to have_no_css ":modal"
      click_on "Cancel"
      # WHY: the + rather than the path, which the refused POST already left the browser on.
      expect(page).to have_button "Add member"
    end

    # WHY: #506 AC6, so a phone's keyboard stays down until the member taps the email field: opening focuses the link's primary control instead.
    it "leaves the email field unfocused on opening" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member

      expect(page).to have_css "#add_member_dialog button:focus", exact_text: "Create new join link"
      expect(page).to have_no_css "#invite_by_email_email:focus"
    end

    # WHY: the frame swap replaces the control that had focus, so the new state's primary control has to take it.
    it "focuses Copy link once the link is created" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Create new join link"

      expect(page).to have_css "#add_member_dialog button:focus", exact_text: "Copy link"
    end

    it "turns Link copied back into Copy link" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Copy link"

      expect(page).to have_css "#add_member_dialog button.btn-secondary", exact_text: "Link copied"
      expect(page).to have_css "#add_member_dialog button.btn-primary", exact_text: "Copy link", wait: 4
    end

    it "says so when the browser refuses the copy" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: denied in the browser context Cuprite opened for this session, for the reason the copy example gives.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-write" }, setting: "denied")
      open_add_member
      click_on "Copy link"

      expect(page).to have_css "[role='status']:not(.sr-only)", text: "Couldn't copy. Select the link and copy it yourself."
    end

    # WHY: #445 AC3, walked in the browser: Regenerate asks first, then shows a link other than the one it retired, in the dialog still open.
    it "regenerates the link once confirmed" do
      member = create(:member, :active, :owner)
      token = JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Regenerate link"
      within("dialog#join_link_regenerate") { click_on "Regenerate" }

      expect(page).to have_no_field "join_link_url", with: new_join_request_url(token:)
      expect(join_link_url).to include "token="
      expect(page).to have_css "dialog#add_member_dialog[open]"
    end

    # WHY: #445 AC2, walked in the browser: Delete asks first, then offers to create a new link in the dialog still open.
    it "deletes the link once confirmed" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Delete link"
      within("dialog#join_link_delete") { click_on "Delete link" }

      expect(page).to have_css "#add_member_dialog button:focus", exact_text: "Create new join link"
      expect(page).to have_css "dialog#add_member_dialog[open]"
    end

    # WHY: a refusal redirects to a page with no `join_link` frame, which Turbo would answer with "Content missing" inside the dialog, so the refusal has to reach the page it redirected to.
    it "shows the refusal when the owner is paused after opening the dialog" do
      member = create(:member, :active, :owner)
      create(:member, :active, :owner, group: member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      member.update!(status: :paused)
      click_on "Create new join link"

      expect(page).to have_text "You are not allowed to do that."
      expect(page).to have_no_css "dialog#add_member_dialog[open]"
    end

    # WHY: the owner's order on #453 that Regenerate asks first, so cancelling it leaves the link working.
    it "keeps the link when Regenerate is cancelled" do
      member = create(:member, :active, :owner)
      token = JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Regenerate link"
      within("dialog#join_link_regenerate") { click_on "Cancel" }

      expect(page).to have_no_css "dialog#join_link_regenerate[open]"
      expect(member.group.reload.join_link.token).to eq token
    end

    # WHY: the owner's order on #453 that Delete asks first, so cancelling it leaves the link working.
    it "keeps the link when Delete is cancelled" do
      member = create(:member, :active, :owner)
      token = JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Delete link"
      within("dialog#join_link_delete") { click_on "Cancel" }

      expect(page).to have_no_css "dialog#join_link_delete[open]"
      expect(member.group.reload.join_link.token).to eq token
    end

    # WHY: the owner's order on #453 that every modal closes from an x beside its title, since neither the sheet nor the dialog can be swiped away.
    it "closes the dialog from its x" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      within("dialog#add_member_dialog") { click_on "Close" }

      expect(page).to have_no_css "dialog#add_member_dialog[open]"
    end

    it "closes a confirmation from its x, keeping the Add member dialog open" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_add_member
      click_on "Delete link"
      within("dialog#join_link_delete") { click_on "Close" }

      expect(page).to have_no_css "dialog#join_link_delete[open]"
      expect(page).to have_css "dialog#add_member_dialog[open]"
    end

    it "paints the dialog with no link in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_add_member

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "#join_link form button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with no link in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_add_member

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "#join_link form button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with a link in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_add_member

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "#join_link button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with a link in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_add_member

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "#join_link button.btn-primary"
      expect(page).to be_accessible
    end
  end

  # WHY: #484. The list takes the events list's structure, so what the browser adds there is walked here too: the tabs, the sheet's count, the chips, the funnel, the stacking and axe in both themes. Who is offered which tab and filter is `spec/requests/members_spec.rb`'s.
  context "with its tabs and filter sheet" do
    # WHY: #484 AC7. Each tab is a link carrying every filter on, so a filter survives switching tabs.
    it "switches tabs with every filter still on" do
      owner  = create(:member, :active, :owner)
      paused = create(:member, :paused, :owner, group: owner.group)
      sign_in_as owner.user

      visit group_members_path(owner.group, role: %w[ owner ])
      click_link "Paused"

      expect(page).to have_current_path(group_members_path(owner.group, status: "paused", role: %w[ owner ])).and have_css("##{ActionView::RecordIdentifier.dom_id(paused, :row)}")
      expect(page).to have_link "Remove Owner"
    end

    # WHY: #484 AC13. The browser's accessibility tree names each tab with what its count counts, while the tab shows the count alone.
    it "names each tab with what its count counts, showing the count alone" do
      owner = create(:member, :active, :owner)
      create(:member, :active, group: owner.group)
      sign_in_as owner.user

      visit group_members_path(owner.group)

      expect(tab_names(%w[ Active Paused Pending Inactive ])).to eq [ "Active (2 members)", "Paused (0 members)", "Pending (0 members)", "Inactive (0 members)" ]
      expect(page.all("nav[aria-label='Member lists'] a").map(&:text)).to eq [ "Active (2)", "Paused (0)", "Pending (0)", "Inactive (0)" ]
    end

    # WHY: the owner's pick on #486: four tabs and their counts do not fit a phone, so the row scrolls sideways and no label wraps.
    it "keeps every tab on one line on a phone, scrolling the row to reach the last" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::MOBILE

      visit group_members_path(owner.group)

      expect(page.evaluate_script(%((() => { const nav = document.querySelector("nav[aria-label='Member lists']"), tabs = [ ...nav.querySelectorAll("a") ], lines = tabs.map(tab => { const range = document.createRange(); range.selectNodeContents(tab); return range.getClientRects().length }); nav.scrollLeft = nav.scrollWidth; const last = tabs.at(-1).getBoundingClientRect(), box = nav.getBoundingClientRect(); return [ lines, nav.scrollWidth > nav.clientWidth, Math.round(last.right) <= Math.round(box.right) ] })()))).to eq [ [ 1, 1, 1, 1 ], true, true ]
    end

    # WHY: a row that scrolls starts at its left edge, so a tab opened past the screen's edge would load cut off; the research on #486 asks for the open tab shown whole.
    it "shows the open tab whole on a phone, even the last" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::MOBILE

      visit group_members_path(owner.group, status: "inactive")

      expect(page.evaluate_script(%((() => { const nav = document.querySelector("nav[aria-label='Member lists']"), tab = nav.querySelector("[aria-current='page']").getBoundingClientRect(), box = nav.getBoundingClientRect(); return [ nav.scrollWidth > nav.clientWidth, tab.left >= box.left, Math.round(tab.right) <= Math.round(box.right) ] })()))).to eq [ true, true, true ]
    end

    # WHY: the owner's pick on #486: where the screen's edge falls decides whether any label is cut, so an arrow marks each end that hides more tabs, and at 320px no label is cut at all.
    it "marks each end of the tabs that hides more with an arrow that slides the row" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      page.current_window.resize_to(320, 844)

      visit group_members_path(owner.group)

      # WHY: both arrows start `hidden` and only `scroll_arrows_controller.js` connecting shows the next one, so the matchers wait for it where a one-shot `evaluate_script` read raced the connect and flaked.
      expect(page).to have_css("nav[aria-label='Member lists'] ~ button:last-of-type", visible: :visible)
      expect(page).to have_css("nav[aria-label='Member lists'] ~ button:first-of-type", visible: :hidden)
      find("nav[aria-label='Member lists'] ~ button:not([hidden])").click
      expect(page).to have_css("nav[aria-label='Member lists'] ~ button:first-of-type:not([hidden])", visible: :all)
      expect(page).to have_css("nav[aria-label='Member lists'] ~ button:last-of-type[hidden]", visible: :all)
    end

    # WHY: the row scrolls only when it must; where the tabs fit they still share its width equally.
    it "spreads the tabs across the row when they fit" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::DESKTOP

      visit group_members_path(owner.group)

      expect(page.evaluate_script(%((() => { const nav = document.querySelector("nav[aria-label='Member lists']"), widths = [ ...nav.querySelectorAll("a") ].map(tab => Math.round(tab.getBoundingClientRect().width)); return [ nav.scrollWidth == nav.clientWidth, Math.max(...widths) - Math.min(...widths) <= 1, Math.abs(widths.reduce((sum, width) => sum + width, 0) - nav.clientWidth) <= 2 ] })()))).to eq [ true, true, true ]
    end

    # WHY: #484 AC11. The tabs and the chips paint differently in each theme.
    it "passes axe on the list with its tabs and chips, in organic" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      prefer_colour_scheme :light

      visit group_members_path(owner.group, role: %w[ owner ])

      expect(page).to have_link("Clear all").and be_accessible
    end

    it "passes axe on the list with its tabs and chips, in organic-dark" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      prefer_colour_scheme :dark

      visit group_members_path(owner.group, role: %w[ owner ])

      expect(page).to have_link("Clear all").and be_accessible
    end

    # WHY: #484 AC11. The sheet is only in the accessibility tree while it is open, which only a browser can make it.
    it "passes axe with the filter sheet open, in organic" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::MOBILE
      prefer_colour_scheme :light

      visit group_members_path(owner.group)
      click_button "Filter members"

      expect(page).to have_css("dialog#member_filter_dialog[open]").and be_accessible
    end

    it "passes axe with the filter sheet open, in organic-dark" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::MOBILE
      prefer_colour_scheme :dark

      visit group_members_path(owner.group)
      click_button "Filter members"

      expect(page).to have_css("dialog#member_filter_dialog[open]").and be_accessible
    end

    # WHY: #484 AC5. The count is fetched as the picks change, so only a browser sees it follow them.
    it "counts the members the sheet's picks would show as they change, then applies them" do
      owner = create(:member, :active, :owner)
      other = create(:member, :active, group: owner.group)
      sign_in_as owner.user

      visit group_members_path(owner.group)
      pick_in_sheet "Owner"

      expect(page).to have_button "Show 1 member"
      click_button "Show 1 member"
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(owner, :row)}").and have_no_css("##{ActionView::RecordIdentifier.dom_id(other, :row)}")
      expect(page).to have_link "Remove Owner"
    end

    # WHY: #484 AC6. A chip links the list with everything else still on, so only its own filter goes.
    it "removes one filter with its chip, leaving the others on" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user

      visit group_members_path(owner.group)
      pick_in_sheet "Owner", "Manages events"
      click_button "Show 0 members"
      click_link "Remove Owner"

      expect(page).to have_no_link("Remove Owner").and have_link("Remove Manages events")
    end

    # WHY: #484 AC6. The chip row's Clear all drops every filter and keeps the tab.
    it "clears every filter from the chip row, keeping the tab" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user

      visit group_members_path(owner.group, status: "paused", role: %w[ administrator ])
      click_link "Clear all"

      expect(page).to have_current_path(group_members_path(owner.group, status: "paused")).and have_no_link("Remove Administrator")
    end

    # WHY: #484 AC6. The sheet's Clear all unticks its picks, not the list's, and the count follows; applying it leaves the tab as it is.
    it "clears every pick in the sheet on Clear all, keeping the tab" do
      owner = create(:member, :active, :owner)
      create(:member, :paused, group: owner.group)
      sign_in_as owner.user

      visit group_members_path(owner.group, status: "paused")
      pick_in_sheet "Owner"
      expect(page).to have_button "Show 0 members"
      click_button "Clear all"
      expect(find_by_id("member_filter_dialog").evaluate_script("this.querySelectorAll('input:checked').length")).to eq 0
      click_button "Show 1 member"

      expect(page).to have_current_path(group_members_path(owner.group, status: "paused"))
    end

    # WHY: #484 AC6. Muted while nothing hides members from the tab picked, primary once a filter does, and either way clearing 3:1 as an icon must.
    it "paints the funnel muted with no filter on and primary with one" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user

      visit group_members_path(owner.group)
      muted = funnel_ink("text-icon-muted")
      pick_in_sheet "Owner"
      click_button "Show 1 member"
      expect(page).to have_link "Remove Owner"

      expect([ muted, funnel_ink("text-primary") ]).to eq [ [ true, true ], [ true, true ] ]
    end

    # WHY: #484 AC3. Side by side while both fit, Clear all on the left; once they do not, "Show N members" goes first, full width, and Clear all under it, as the events sheet's do.
    it "stacks the sheet's buttons Show first once they no longer fit side by side" do
      owner = create(:member, :active, :owner)
      sign_in_as owner.user
      resize_to ViewportHelper::MOBILE

      visit group_members_path(owner.group)
      click_button "Filter members"
      clear, show = sheet_buttons
      resize_to [ 260, 700 ]
      narrow_clear, narrow_show = sheet_buttons

      expect([ clear.top == show.top && clear.left < show.left, narrow_show.top < narrow_clear.top ]).to eq [ true, true ]
    end
  end
end
