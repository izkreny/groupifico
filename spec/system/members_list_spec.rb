require "rails_helper"

# Only what a browser adds. Who sees the "not signed in yet" mark, the count, Invite, the pencil
# and the toggle, which members are listed and in what order, are `spec/requests/members_spec.rb`'s
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

  it "paints the roster in light, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(actor, :row)} .badge"
    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(paused, :row)}"
    expect(page).to be_accessible
  end

  it "paints the roster in dark, its paused row dimmed and still readable" do
    actor  = create(:member, :active, :owner, :with_all_attributes)
    paused = create(:member, :paused, :with_all_attributes, group: actor.group)
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_members_path(actor.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(actor, :row)} .badge"
    expect(page).to have_css "##{ActionView::RecordIdentifier.dom_id(paused, :row)}"
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

  # WHY: the join link's controls sit beneath Invite on this page for an owner. Which state draws which control, and for whom, is `spec/requests/members_spec.rb`'s; what is left is that Copy puts the link on the clipboard and that each button lands where it says.
  context "with the join link" do
    # WHY: #445 AC1, walked in the browser, since only the browser can tell that Copy wrote the clipboard.
    it "copies the link" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: reading the clipboard back needs its permission, granted in the browser context Cuprite opened for this session rather than Chrome's default one, where a grant reaches no page here.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-read" }, setting: "granted")
      click_on "Turn on join link"
      link = find_field("Anyone with this link can ask to join. Regenerate it to stop the old one working.").value
      click_on "Copy"

      expect(page).to have_css "[role='status']", text: "Copied"
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq link
    end

    it "says so when the browser refuses the copy" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: denied in the browser context Cuprite opened for this session, for the reason the copy example gives.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-write" }, setting: "denied")
      click_on "Copy"

      expect(page).to have_css "[role='status']", text: "Couldn't copy. Select the link and copy it yourself."
    end

    # WHY: #445 AC3, walked in the browser: Regenerate lands back on the members page showing a link other than the one it retired.
    it "shows a new link once regenerated" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      click_on "Turn on join link"
      first = find_field("Anyone with this link can ask to join. Regenerate it to stop the old one working.").value
      click_on "Regenerate"

      expect(page).to have_field("Anyone with this link can ask to join. Regenerate it to stop the old one working.", with: /token=/)
      expect(page).to have_no_field("Anyone with this link can ask to join. Regenerate it to stop the old one working.", with: first)
    end

    # WHY: #445 AC2, walked in the browser: Turn off lands back on the members page offering to turn the link on.
    it "offers to turn the link on again once turned off" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      click_on "Turn off"

      expect(page).to have_text "Join link turned off."
      expect(page).to have_button "Turn on join link"
    end

    it "paints a link that is off in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "form[action='#{group_join_link_path(member.group)}'] button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints a link that is off in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "form[action='#{group_join_link_path(member.group)}'] button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints a link that is on in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "form[action='#{group_join_link_path(member.group)}'] button.btn:not(.btn-ghost)"
      expect(page).to be_accessible
    end

    it "paints a link that is on in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "form[action='#{group_join_link_path(member.group)}'] button.btn:not(.btn-ghost)"
      expect(page).to be_accessible
    end
  end
end
