require "rails_helper"

# One file for the Me screen and Edit me, because they are one flow: the Account row leads to the
# form and its Save leads back.
#
# Only what a browser adds. Which rows the screen offers, that none of the reader's groups is
# listed, which fields the form draws and where a refused email's message lands are all
# `spec/requests/user_profiles_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left is that the controls paint, that
# each row lands where it says, and that a refused save's messages are visible rather than merely
# present. The block naming solely owned groups and the delete sheet are
# `spec/system/account_deletion_spec.rb`'s.
RSpec.describe "The Me screen", type: :system do
  it "paints in light, with no accessibility violations" do
    user = create(:user)
    sign_in_as user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit user_profile_path

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "main .avatar > div"
    expect(page).to paint "a[href='#{new_group_path}']"
    expect(page).to be_accessible
  end

  it "paints in dark, with no accessibility violations" do
    user = create(:user)
    sign_in_as user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit user_profile_path

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "main .avatar > div"
    expect(page).to paint "a[href='#{new_group_path}']"
    expect(page).to be_accessible
  end

  it "keeps every row and line inside a phone's width" do
    sign_in_as create(:member, :owner).user
    resize_to ViewportHelper::MOBILE

    visit user_profile_path

    expect(page).to have_css "#solely_owned_groups"
    expect(horizontal_overflow).to eq 0
  end

  it "lands on Edit me from the Account row" do
    sign_in_as create(:user)

    visit user_profile_path
    click_link "Edit name, mobile and email"

    expect(page).to have_current_path edit_user_profile_path
  end

  it "lands on the new group screen from Create group" do
    sign_in_as create(:user)

    visit user_profile_path
    click_link "Create group"

    expect(page).to have_current_path new_group_path
  end

  it "signs the reader out from the Sign out row" do
    sign_in_as create(:user)

    visit user_profile_path
    click_button "Sign out"

    expect(page).to have_current_path new_session_path
  end

  describe "Edit me" do
    it "paints in light, with no accessibility violations" do
      sign_in_as create(:user)
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "input[type=submit]"
      expect(page).to be_accessible
    end

    it "paints in dark, with no accessibility violations" do
      sign_in_as create(:user)
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "input[type=submit]"
      expect(page).to be_accessible
    end

    it "lands back on Me with the new name when saved" do
      sign_in_as create(:user)

      visit edit_user_profile_path
      fill_in "First name", with: "Ada"
      fill_in "Last name", with: "Lovelace"
      click_button "Save"

      expect(page).to have_current_path user_profile_path
      expect(page).to have_css "h1", text: "Ada Lovelace"
    end

    it "returns to Me when cancelled" do
      sign_in_as create(:user)

      visit edit_user_profile_path
      click_link "Cancel"

      expect(page).to have_current_path user_profile_path
    end

    # Frame 9h2's state, with one real refusal per record: the mobile is the profile's, the email
    # the account's. The email is a taken address rather than a malformed one, because the email
    # field's own constraint stops a malformed one in the browser before the server sees it.
    it "paints a refused save's messages under their fields and the summary on top" do
      create(:user, email: "taken@example.com")
      sign_in_as create(:user)

      visit edit_user_profile_path
      fill_in "Mobile", with: "1" * 51
      fill_in "Email", with: "taken@example.com"
      click_button "Save"

      expect(page).to have_css "#user_profile_mobile_phone_error", text: "Mobile phone is too long"
      expect(page).to have_css "#user_profile_user_attributes_email_error", text: "Email has already been taken"
      expect(page).to paint "#error_explanation"
      expect(page).to be_accessible
    end
  end
end
