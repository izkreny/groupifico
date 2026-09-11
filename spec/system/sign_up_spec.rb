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

    # The one entry screen whose copy still goes through `AppFormBuilder#note_tag`, which renders
    # its hint with daisyUI's `label` - the nowrap component every other screen here had taken off
    # it. The group-name hint fits today, 281px of text in 358px, so this guards the mechanism
    # rather than a live defect. `spec/system/sign_in_page_spec.rb` carries why no other matcher
    # sees it, and why the width is stated before the page is opened rather than after.
    it "does not scroll sideways at phone width" do
      resize_to ViewportHelper::MOBILE
      visit new_sign_up_path

      expect(horizontal_overflow).to eq 0
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
    let(:link) { sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Riverside Choir")) }

    before do
      visit link
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
    #
    # Both values are literals, and long ones: an email has no break opportunity in it and a group
    # name need not either, so this heading's fit is decided by their length and nothing else.
    # `spec/system/authentication_spec.rb` carries why a factory's value would make the guard pass
    # or fail by running order.
    it "does not scroll sideways at phone width" do
      resize_to ViewportHelper::MOBILE
      visit sign_up_confirmation_path(token: SignUp.mint(
        email: "kassandra.wetherington.blythe@example.com", group_name: "Riverside Chamber Choir"))

      expect(horizontal_overflow).to eq 0
    end

    # The one navigation in this flow a request spec cannot make: the button spends the link and
    # lands on the group it just created.
    #
    # The shape of the path rather than `group_path(Group.sole)`, which is an argument and so is
    # read once, before `have_current_path` starts retrying: a click that returns before
    # `SignUp.redeem!` commits would raise `RecordNotFound` where the matcher would have waited.
    # Which group it is belongs to `spec/requests/sign_up_confirmations_spec.rb`, which already
    # asserts the redirect names it.
    it "lands on the new group" do
      click_button "Sign in and create group"

      expect(page).to have_current_path %r{\A/groups/\d+\z}
    end
  end
end
