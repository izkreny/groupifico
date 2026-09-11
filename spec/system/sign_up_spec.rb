require "rails_helper"

# The other half of the entry flow, and the half nothing under `spec/system` reached: the form and
# its confirmation page are one flow, so they are one file per `.agents/testing.md`.
#
# Only what a browser adds. Which fields the form carries, that the submission writes nothing, and
# that the confirmation page names both the address and the group are `spec/requests/sign_ups_spec
# .rb` and `spec/requests/sign_up_confirmations_spec.rb`'s assertions, and the duplication rule
# keeps them there. What is left is whether a reader can see any of it.
RSpec.describe "Creating a group", type: :system do
  describe "the form" do
    before do
      visit new_sign_up_path
    end

    it "paints the submit button" do
      expect(page).to paint "input[type=submit]"
    end

    # The screen with the most to get wrong: two labelled controls, and a hint the form builder
    # wires to its field through `aria-describedby`.
    it "has no accessibility violations" do
      expect(page).to be_accessible
    end

    # Named for what it asserts. That the answer is identical whether or not the address is already
    # in use is the request spec's to prove, and nothing here reads the copy.
    it "paints the notice after a submission" do
      fill_in "Your email", with: "starter@example.com"
      fill_in "Group name", with: "Riverside Choir"
      click_button "Send my confirmation link"

      expect(page).to have_css "#notice"
      expect(page).to paint "#notice"
    end
  end

  describe "the page the confirmation link opens" do
    before do
      visit sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Riverside Choir"))
    end

    it "paints the button that creates the group" do
      expect(page).to paint ".btn-primary"
    end

    it "has no accessibility violations" do
      expect(page).to be_accessible
    end

    # `spec/system/sign_in_page_spec.rb` carries why this is a separate assertion from the two
    # above. This screen's heading names an address and a group name, so it is the one most likely
    # to grow past the column later.
    it "does not scroll sideways at phone width" do
      resize_to ViewportHelper::MOBILE

      expect(horizontal_overflow).to eq 0
    end

    # The one navigation in this flow a request spec cannot make: the button spends the link and
    # lands on the group it just created.
    it "lands on the new group" do
      click_button "Sign in and create group"

      expect(page).to have_current_path group_path(Group.sole)
    end
  end
end
