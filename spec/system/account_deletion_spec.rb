require "rails_helper"

# Only what a browser adds. What the sheet says, that it is blocked while a group is owned alone,
# where the delete and its refusal redirect and what their flashes say are all
# `spec/requests/user_profiles_spec.rb`'s and `spec/requests/user_spec.rb`'s assertions, and per the
# duplication rule in `.agents/testing.md` none of them comes back here. Opening, Escape and the
# backdrop are the shared sheet's, proven once in `spec/system/confirm_sheet_spec.rb`.
#
# What a request spec cannot reach is whether the primary enables on the word, and whether each
# message is *visible*: every element keeps its text in the DOM under a class the stylesheet never
# compiled, so every request spec stays green while a person sees nothing, and the paint assertions
# are what go red. Measured, not assumed, for the block in the sheet: its `alert alert-error` was
# swapped for a class Tailwind never compiled, and the paint assertion failed at a contrast ratio
# of 1 while `spec/requests/user_profiles_spec.rb` stayed green.
#
# `be_accessible` is the standing assertion `.agents/testing.md` puts on every spec covering a
# screen, and the matcher's own failure is watched in `spec/system/axe_matcher_spec.rb` rather than
# re-established here.
RSpec.describe "Deleting my account", type: :system do
  include ActionView::RecordIdentifier

  context "when the reader owns no group alone" do
    let(:user) { create(:member, group: create(:group, name: "Ninth Street Band")).user }

    before do
      sign_in_as user

      visit user_profile_path
      within("##{dom_id(user, :confirm_delete)}_form") { click_button "Delete my account" }
    end

    it "has no accessibility violations with the sheet open" do
      expect(page).to have_css "dialog[open]"
      expect(page).to be_accessible
    end

    it "enables the primary only once the field reads exactly DELETE, and paints it then" do
      fill_in "Type DELETE to confirm", with: "delete"
      expect(page).to have_button "Delete my account", disabled: true

      fill_in "Type DELETE to confirm", with: "DELETE"
      expect(page).to have_css ".modal-action .btn-error:enabled"
      expect(page).to paint ".modal-action .btn-error"
    end

    # The field belongs to no form, so Enter has nothing to submit. Owned by the trigger's form, it
    # would submit through the trigger, which is never disabled, and delete without the word.
    #
    # Observed as the submit event rather than as the account surviving: the delete Turbo would
    # send is asynchronous, so a read of the database right after the key races it and passes
    # either way. Implicit submission fires `submit` inside the key's own dispatch, and `window`
    # outlives the visit that would follow, so the record is there to read.
    it "submits nothing when Enter is pressed in the field without the word" do
      fill_in "Type DELETE to confirm", with: "delete"
      page.execute_script "window.submitted = false; document.addEventListener('submit', () => { window.submitted = true }, true)"

      find_field("Type DELETE to confirm").send_keys(:enter)

      expect(page.evaluate_script("window.submitted")).to be false
    end

    it "deletes the account and paints the sign-in form's notice" do
      fill_in "Type DELETE to confirm", with: "DELETE"
      within(".modal-action") { click_button "Delete my account" }

      expect(page).to have_current_path new_session_path
      expect(page).to paint "#notice"
      expect(User.where(id: user.id)).not_to exist
    end

    it "starts over from an empty field when the sheet is dismissed and opened again" do
      fill_in "Type DELETE to confirm", with: "DELETE"
      within(".modal-action") { click_button "Keep my account" }
      expect(page).to have_no_css "dialog[open]"

      within("##{dom_id(user, :confirm_delete)}_form") { click_button "Delete my account" }

      expect(page).to have_field "Type DELETE to confirm", with: ""
      expect(page).to have_button "Delete my account", disabled: true
    end

    # Asserted at `turbo:before-cache`, for the reason `spec/system/confirm_sheet_spec.rb` gives for
    # its own history example: the restored page is transient, so a read taken on it races the
    # restore. The listener is added after the controller's own, so it runs after the reset.
    it "does not leave the word typed in the page Turbo caches" do
      fill_in "Type DELETE to confirm", with: "DELETE"
      page.execute_script <<~JAVASCRIPT
        window.cachedWord = null
        document.addEventListener("turbo:before-cache", () => {
          window.cachedWord = document.querySelector("dialog input").value
        })
      JAVASCRIPT

      page.execute_script "Turbo.visit('#{new_group_path}')"
      expect(page).to have_current_path new_group_path

      expect(page.evaluate_script("window.cachedWord")).to eq ""
    end

    it "keeps the account when Keep my account is used" do
      within(".modal-action") { click_button "Keep my account" }

      expect(page).to have_no_css "dialog[open]"
      expect(User.where(id: user.id)).to exist
    end
  end

  context "when the reader is a group's only active owner" do
    let(:member) { create(:member, :owner, group: create(:group, name: "Riverside Choir")) }

    before do
      sign_in_as member.user

      visit user_profile_path
      within("##{dom_id(member.user, :confirm_delete)}_form") { click_button "Delete my account" }
    end

    it "paints the block and keeps the primary disabled whatever is typed" do
      fill_in "Type DELETE to confirm", with: "DELETE"

      expect(page).to paint "##{dom_id(member.user, :confirm_delete)}_block"
      expect(page).to have_button "Delete my account", disabled: true
    end

    it "has no accessibility violations with the sheet open" do
      expect(page).to have_css "dialog[open]"
      expect(page).to be_accessible
    end

    # The box's own scroll width rather than `horizontal_overflow`: the sheet sits in the top layer,
    # outside the document's scroll width, and `modal-box` scrolls whatever overflows it, so the
    # document reads 0 whatever the sheet holds - watched passing with the block forced onto one
    # line, where this read fails.
    it "keeps the open sheet's content inside a phone's width" do
      resize_to ViewportHelper::MOBILE

      expect(page).to have_css "##{dom_id(member.user, :confirm_delete)}_block"
      expect(page.evaluate_script("(box => box.scrollWidth - box.clientWidth)(document.querySelector('dialog[open] .modal-box'))")).to eq 0
    end
  end

  # The one browser path left to the refusal: the block was not true when the sheet rendered, so
  # the primary enabled, and it became true before the press.
  it "paints the refusal's alert when a co-owner leaves between the sheet opening and the press" do
    member = create(:member, :owner)
    co_owner = create(:member, :owner, group: member.group)
    sign_in_as member.user
    visit user_profile_path
    within("##{dom_id(member.user, :confirm_delete)}_form") { click_button "Delete my account" }
    fill_in "Type DELETE to confirm", with: "DELETE"

    co_owner.inactive!
    within(".modal-action") { click_button "Delete my account" }

    expect(page).to have_css "#alert"
    expect(page).to paint "#alert"
  end
end
