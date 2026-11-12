require "rails_helper"

# One file for the two screens, because they render one `groups/_form` and the branches that
# separate them are the subject.
#
# Only what a browser adds. Which segments the control offers, what it preselects, whether the
# type is text or a control, which of the address's two shapes is drawn and who sees the delete
# are all `spec/requests/groups_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left is the part no request spec can
# see: that a `.join` of radios painted as buttons rather than as bare dots, that choosing a
# segment actually changes the answer the form will submit, that the pencil and the delete are
# controls a person can use and land where they say, and that a refused save comes back with what
# was typed still in the fields.
RSpec.describe "The group form", type: :system do
  # `.btn` on a radio is the whole claim: the class is in the markup either way, and only the
  # browser knows whether daisyUI drew a button face or left three 16px dots. Both dimensions,
  # because a `join-item` that lost its `btn` still has the input's own width.
  it "paints the type as a row of buttons rather than as bare radios" do
    sign_in_as create(:user)

    visit new_group_path
    box = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const r = document.querySelector(".join input[type=radio]").getBoundingClientRect();
        return [ Math.round(r.width), Math.round(r.height) ];
      })()
    JAVASCRIPT

    expect(box.first).to be > 40
    expect(box.last).to be > 24
  end

  it "paints the new group screen in light, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_group_path

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".join input[type=radio]:checked"
    expect(page).to be_accessible
  end

  it "paints the new group screen in dark, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_group_path

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".join input[type=radio]:checked"
    expect(page).to be_accessible
  end

  # The control is three inputs sharing one name, so "only one answer survives" is a browser fact
  # rather than a markup one. Asserting the submitted record is what makes it about the form.
  it "sends the segment the reader chose rather than the one it opened on" do
    sign_in_as create(:user)

    visit new_group_path
    fill_in "group_name", with: "Riverside Choir"
    find(".join input[type=radio][value='band']").click
    click_button "Create group"

    expect(page).to have_current_path group_path(Group.sole)
    expect(Group.sole.group_type).to eq "band"
  end

  it "keeps every typed value when the save is refused" do
    sign_in_as create(:user)

    visit new_group_path
    find(".join input[type=radio][value='choir']").click
    fill_in "group_description", with: "Tuesdays at the hall."
    fill_in "group_address_attributes_city", with: "Springfield"
    click_button "Create group"

    expect(page).to have_css "#group_name_error"
    expect(page).to have_field "group_description", with: "Tuesdays at the hall."
    expect(page).to have_field "group_address_attributes_city", with: "Springfield"
    expect(page).to have_css ".join input[type=radio][value='choir']:checked", visible: :all
  end

  # The failure `spec/support/viewport_helper.rb` records from #245, which this screen reproduced:
  # daisyUI's `.label` is `white-space: nowrap`, so the hint's box stays inside the column while
  # its text runs off the screen. Every box measurement reports the page as clean and only the
  # document's own scroll width knows, which is what `horizontal_overflow` reads.
  it "keeps the type hint inside a phone's width" do
    sign_in_as create(:user)
    resize_to ViewportHelper::MOBILE

    visit new_group_path

    expect(page).to have_css "#group_group_type_hint"
    expect(horizontal_overflow).to eq 0
  end

  it "returns to the groups index when the new group screen is cancelled" do
    sign_in_as create(:user)

    visit new_group_path
    click_link "Cancel"

    expect(page).to have_current_path groups_path
  end

  # "Cancel | Create group" fits a phone's 358px row: half of it each, less the 8px gap.
  it "shares one line equally between the new group screen's two buttons on a phone" do
    sign_in_as create(:user)
    resize_to ViewportHelper::MOBILE

    visit new_group_path

    expect(page).to have_button "Create group"
    expect(form_actions_layout).to eq({ "buttons" => [ [ "Cancel", 175 ], [ "Create group", 175 ] ], "lines" => 1 })
  end

  context "when the group already exists" do
    # "Delete group | Cancel | Save changes" fits the 508px row a 540px window leaves, which Edit profile's wider row does not. Three equal shares of 508px less two 8px gaps.
    it "shares one line equally between its three buttons where they fit" do
      member = create(:member, :active, :owner, :with_all_attributes)
      sign_in_as member.user
      resize_to [ 540, 900 ]

      visit edit_group_path(member.group)

      expect(page).to have_button "Delete group"
      expect(form_actions_layout).to eq({ "buttons" => [ [ "Delete group", 164 ], [ "Cancel", 164 ], [ "Save changes", 164 ] ], "lines" => 1 })
    end

    it "paints it in light, with no accessibility violations" do
      member = create(:member, :active, :owner, :with_all_attributes)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit edit_group_path(member.group)

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint ".card"
      expect(page).to be_accessible
    end

    it "paints it in dark, with no accessibility violations" do
      member = create(:member, :active, :owner, :with_all_attributes)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit edit_group_path(member.group)

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint ".card"
      expect(page).to be_accessible
    end

    it "lands on the address's own form when the pencil is used" do
      member = create(:member, :active, :owner, :with_all_attributes)
      sign_in_as member.user

      visit edit_group_path(member.group)
      find("a[aria-label='Correct address']").click

      expect(page).to have_current_path edit_address_path(member.group.address)
    end

    it "draws the address's pencil at 20px, as every icon control" do
      member = create(:member, :active, :owner, :with_all_attributes)
      sign_in_as member.user

      visit edit_group_path(member.group)

      expect(width_of("a[aria-label='Correct address'] svg")).to eq 20
    end

    it "returns to the group home when the edit screen is cancelled" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit edit_group_path(member.group)
      click_link "Cancel"

      expect(page).to have_current_path group_path(member.group)
    end
  end

  # WHY: the join link's controls sit beneath this form on the edit screen. Which state draws which control is `spec/requests/groups_spec.rb`'s; what is left is that Copy puts the link on the clipboard and that each button lands where it says.
  context "with the join link" do
    # WHY: #445 AC1, walked in the browser, since only the browser can tell that Copy wrote the clipboard.
    it "copies the link just turned on" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit edit_group_path(member.group)
      # WHY: reading the clipboard back needs its permission, granted in the browser context Cuprite opened for this session rather than Chrome's default one, where a grant reaches no page here.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: "clipboard-read" }, setting: "granted")
      click_on "Turn on join link"
      link = find_field("Share this link. It is shown only now, so copy it before you leave this page.").value
      click_on "Copy"

      expect(page).to have_css "[role='status']", text: "Copied"
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq link
    end

    # WHY: #445 AC3, walked in the browser: Regenerate lands back on the edit screen showing a link other than the one it retired.
    it "shows a new link once regenerated" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit edit_group_path(member.group)
      click_on "Turn on join link"
      first = find_field("Share this link. It is shown only now, so copy it before you leave this page.").value
      click_on "Regenerate"

      expect(page).to have_field("Share this link. It is shown only now, so copy it before you leave this page.", with: /token=/)
      expect(page).to have_no_field("Share this link. It is shown only now, so copy it before you leave this page.", with: first)
    end

    # WHY: #445 AC2, walked in the browser: Turn off lands back on the edit screen offering to turn the link on.
    it "offers to turn the link on again once turned off" do
      member = create(:member, :active, :owner)
      JoinLink.mint(member.group)
      sign_in_as member.user

      visit edit_group_path(member.group)
      click_on "Turn off"

      expect(page).to have_text "Join link turned off."
      expect(page).to have_button "Turn on join link"
    end

    it "paints the link just turned on in light, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit edit_group_path(member.group)
      click_on "Turn on join link"

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "button[data-action='clipboard#copy']"
      expect(page).to be_accessible
    end

    it "paints the link just turned on in dark, with no accessibility violations" do
      member = create(:member, :active, :owner)
      sign_in_as member.user
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit edit_group_path(member.group)
      click_on "Turn on join link"

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "button[data-action='clipboard#copy']"
      expect(page).to be_accessible
    end
  end
end
