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

  it "returns to the groups index when the new group screen is cancelled" do
    sign_in_as create(:user)

    visit new_group_path
    click_link "Cancel"

    expect(page).to have_current_path groups_path
  end

  context "when the group already exists" do
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

    it "returns to the group home when the edit screen is cancelled" do
      member = create(:member, :active, :owner)
      sign_in_as member.user

      visit edit_group_path(member.group)
      click_link "Cancel"

      expect(page).to have_current_path group_path(member.group)
    end

    # The sheet's own behaviour is `spec/system/confirm_sheet_spec.rb`'s. What belongs here is that
    # this screen is now a place it opens from, and that confirming leaves the reader somewhere
    # that still exists - the group whose page they were on having just been deleted.
    it "deletes the group from the sheet and lands on the groups index" do
      member = create(:member, :active, :owner)
      group  = member.group
      sign_in_as member.user

      visit edit_group_path(group)
      within("##{ActionView::RecordIdentifier.dom_id(group, :confirm_delete)}_form") { click_button "Delete group" }
      within(".modal-action") { click_button "Delete group" }

      expect(page).to have_current_path groups_path
      expect(Group.where(id: group.id)).not_to exist
    end
  end
end
