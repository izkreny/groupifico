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

  # WHY: the join link lives in a dialog the owner opens from beside Invite on this page. Which state draws which control, and for whom, is `spec/requests/members_spec.rb`'s; what is left is that the dialog stays open through each action, that Copy puts the link on the clipboard, and that Regenerate and Delete ask first.
  context "with the join link" do
    def open_join_link
      click_on "Join link"
      expect(page).to have_css "dialog#join_link_dialog[open]"
    end

    def join_link_url = find_by_id("join_link_url").value

    # WHY: #445 AC1, walked in the browser, since only the browser can tell that Copy wrote the clipboard, and that creating the link leaves its dialog open to copy from.
    it "creates and copies the link" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: reading the clipboard back needs its permission, granted in the browser context Cuprite opened for this session rather than Chrome's default one, where a grant reaches no page here.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-read" }, setting: "granted")
      open_join_link
      click_on "Create new join link"
      click_on "Copy link"

      expect(page).to have_css "dialog#join_link_dialog[open]"
      expect(page).to have_css "#join_link_dialog button.btn-secondary", exact_text: "Link copied"
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq join_link_url
    end

    it "turns Link copied back into Copy link" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_join_link
      click_on "Copy link"

      expect(page).to have_css "#join_link_dialog button.btn-secondary", exact_text: "Link copied"
      expect(page).to have_css "#join_link_dialog button.btn-primary", exact_text: "Copy link", wait: 4
    end

    it "says so when the browser refuses the copy" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      # WHY: denied in the browser context Cuprite opened for this session, for the reason the copy example gives.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-write" }, setting: "denied")
      open_join_link
      click_on "Copy link"

      expect(page).to have_css "[role='status']:not(.sr-only)", text: "Couldn't copy. Select the link and copy it yourself."
    end

    # WHY: #445 AC3, walked in the browser: Regenerate asks first, then shows a link other than the one it retired, in the dialog still open.
    it "regenerates the link once confirmed" do
      member = create(:member, :active, :owner)
      token = JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_join_link
      click_on "Regenerate link"
      within("dialog#join_link_regenerate") { click_on "Regenerate" }

      expect(page).to have_no_field "join_link_url", with: new_join_request_url(token:)
      expect(join_link_url).to include "token="
      expect(page).to have_css "dialog#join_link_dialog[open]"
    end

    # WHY: #445 AC2, walked in the browser: Delete asks first, then offers to create a new link in the dialog still open.
    it "deletes the link once confirmed" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_join_link
      click_on "Delete link"
      within("dialog#join_link_delete") { click_on "Delete link" }

      expect(page).to have_button "Create new join link"
      expect(page).to have_css "dialog#join_link_dialog[open]"
      expect(member.group.reload.join_link).to be_nil
    end

    # WHY: the owner's order on #453 that Regenerate asks first, so cancelling it leaves the link working.
    it "keeps the link when Regenerate is cancelled" do
      member = create(:member, :active, :owner)
      token = JoinLink.mint(member.group)
      sign_in_as member.user

      visit group_members_path(member.group)
      open_join_link
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
      open_join_link
      click_on "Delete link"
      within("dialog#join_link_delete") { click_on "Cancel" }

      expect(page).to have_no_css "dialog#join_link_delete[open]"
      expect(member.group.reload.join_link.token).to eq token
    end

    it "paints the dialog with no link in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_join_link

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "#join_link_dialog form button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with no link in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_join_link

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "#join_link_dialog form button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with a link in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_join_link

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "#join_link_dialog button.btn-primary"
      expect(page).to be_accessible
    end

    it "paints the dialog with a link in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit group_members_path(member.group)
      open_join_link

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "#join_link_dialog button.btn-primary"
      expect(page).to be_accessible
    end
  end
end
