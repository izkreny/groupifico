require "rails_helper"

# One file for the avatar's menu and Edit profile, because they are one flow: the menu's Edit profile row leads to the form and its Save leads home.
#
# Only what a browser adds. Which rows the menu offers, which fields the form draws, the button row's order and where a refused email's message lands are all `spec/requests/user_profiles_spec.rb`'s assertions, and per the duplication rule in `.agents/testing.md` none of them comes back here. What is left is that the controls paint, that each row lands where it says, and that a refused save's messages are visible rather than merely present. The block naming solely owned groups and the delete sheet are `spec/system/account_deletion_spec.rb`'s.
RSpec.describe "The Me menu", type: :system do
  # WHY: waited until the menu's fade-in finishes, because axe measures the colours it sees, and halfway through the fade the rows read against a blend of the menu and the page behind it.
  def open_me_menu
    find("#me-menu summary").click
    expect(page).to have_css "#me-menu[open] .dropdown-content", style: { opacity: "1" }
  end

  it "paints in light, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit root_path
    open_me_menu

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "#me-menu summary > div"
    expect(page).to be_accessible
  end

  it "paints in dark, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit root_path
    open_me_menu

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "#me-menu summary > div"
    expect(page).to be_accessible
  end

  # WHY: a member with no name is headed by the email's local part, one word with nowhere to break, so a fixed long one fails on every run where a Faker draw only failed on some.
  it "keeps the open menu inside a phone's width" do
    sign_in_as create(:user, email: "maximilian.featherstonehaugh-wolstenholme@example.com")
    resize_to ViewportHelper::MOBILE

    visit root_path
    open_me_menu

    expect(horizontal_overflow).to eq 0
    expect(page.evaluate_script("document.querySelector('#me-menu .dropdown-content').getBoundingClientRect().left")).to be >= 0
  end

  it "lands on Edit profile from its row" do
    sign_in_as create(:user)

    visit root_path
    open_me_menu
    click_link "Edit profile"

    expect(page).to have_current_path edit_user_profile_path
  end

  it "lands on the feedback form from Send feedback" do
    sign_in_as create(:user)

    visit root_path
    open_me_menu
    click_link "Send feedback"

    expect(page).to have_current_path new_feedback_path
  end

  it "lands on the new group screen from New group" do
    sign_in_as create(:user)

    visit root_path
    open_me_menu
    within("#me-menu") { click_link "New group" }

    expect(page).to have_current_path new_group_path
  end

  it "signs the member out from Sign out" do
    sign_in_as create(:user)

    visit root_path
    open_me_menu
    click_button "Sign out"

    expect(page).to have_current_path new_session_path
  end

  describe "Edit profile" do
    it "paints in light, with no accessibility violations" do
      sign_in_as create(:user)
      prefer_colour_scheme :light
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to paint "button.btn-primary[type=submit]"
      expect(page).to paint "main .avatar > div"
      expect(page).to be_accessible
    end

    it "paints in dark, with no accessibility violations" do
      sign_in_as create(:user)
      prefer_colour_scheme :dark
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(rendered_colour_scheme).to eq "dark"
      expect(page).to paint "button.btn-primary[type=submit]"
      expect(page).to paint "main .avatar > div"
      expect(page).to be_accessible
    end

    it "keeps every row and line inside a phone's width" do
      sign_in_as create(:user, email: "maximilian.featherstonehaugh-wolstenholme@example.com")
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(page).to have_button "Delete my account"
      expect(horizontal_overflow).to eq 0
    end

    # The widest button row in the app, so it is the one that decides where a row led by Delete stops fitting. The column is 608px at `DESKTOP`, three equal shares of it less two 8px gaps.
    it "shares one line equally between its three buttons on a desktop" do
      sign_in_as create(:user)
      resize_to ViewportHelper::DESKTOP

      visit edit_user_profile_path

      expect(page).to have_button "Delete my account"
      expect(form_actions_layout).to eq({ "buttons" => [ [ "Delete my account", 197 ], [ "Cancel", 197 ], [ "Save", 197 ] ], "lines" => 1 })
    end

    it "stacks its buttons full width on a phone, Save on top and Delete my account at the bottom" do
      sign_in_as create(:user)
      resize_to ViewportHelper::MOBILE

      visit edit_user_profile_path

      expect(page).to have_button "Delete my account"
      expect(form_actions_layout).to eq({ "buttons" => [ [ "Save", 358 ], [ "Cancel", 358 ], [ "Delete my account", 358 ] ], "lines" => 3 })
    end

    it "lands home with the new name in the menu when saved" do
      sign_in_as create(:user)

      visit edit_user_profile_path
      fill_in "First name", with: "Ada"
      fill_in "Last name", with: "Lovelace"
      click_button "Save"

      expect(page).to have_current_path root_path
      expect(page).to have_css "#me-menu summary[aria-label='AL, me']"
    end

    it "returns home when cancelled" do
      sign_in_as create(:user)

      visit edit_user_profile_path
      click_link "Cancel"

      expect(page).to have_current_path root_path
    end

    # Frame 9h2's state, with one real refusal per record: the mobile is the profile's, the email the account's. The email is a taken address rather than a malformed one, because the email field's own constraint stops a malformed one in the browser before the server sees it.
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
    end

    it "has no accessibility violations after a refused save, in light" do
      create(:user, email: "taken@example.com")
      sign_in_as create(:user)
      prefer_colour_scheme :light

      visit edit_user_profile_path
      fill_in "Mobile", with: "1" * 51
      fill_in "Email", with: "taken@example.com"
      click_button "Save"

      expect(rendered_colour_scheme).to eq "light"
      expect(page).to be_accessible
    end
  end
end
