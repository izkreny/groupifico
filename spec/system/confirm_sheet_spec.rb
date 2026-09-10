require "rails_helper"

# The sheet is one partial rendered by four screens, so it is covered once here rather than in each
# screen's own file. The group is the subject because its delete is the plainest of the four: no
# typed word, and the record's absence afterwards is a single query.
#
# Every example here is a claim about a browser: that a `<dialog>` opens at all, that Escape and a
# backdrop click close it, and that a dismissed sheet leaves the record alone. Who may delete a
# group, and the markup that carries the no-JavaScript path, are both `spec/requests/groups_spec.rb`'s,
# and per the duplication rule in `.agents/testing.md` neither comes back here.
RSpec.describe "The confirm sheet", type: :system do
  include ActionView::RecordIdentifier

  # The two helpers the history example needs. Arrival is setup rather than the behaviour under
  # test, and the recording is what makes that example deterministic: the restored panel is
  # transient, so a client-side read after the fact races it in both directions - watched flaking
  # on a one-shot read, and watched passing wrongly on `have_no_css`, which waits it out. Taking
  # the observation in the browser at `turbo:render` removes the timing from the assertion, and
  # `window` survives a Turbo restore, so the record is still there to read.
  def arrive_at_the_sheet_through_the_index(group)
    visit groups_path
    click_link "Show"
    within("##{dom_id(group, :confirm_delete)}_form") { click_button "Delete group" }
    expect(page).to have_css "dialog[open]"
  end

  def record_what_gets_cached
    page.execute_script <<~JAVASCRIPT
      window.cachedWithSheetOpen = null
      document.addEventListener("turbo:before-cache", () => {
        window.cachedWithSheetOpen = !!document.querySelector("dialog[open]")
      })
    JAVASCRIPT
  end

  # Outside the opened context deliberately: the promise has to be on the trigger *before* it is
  # used, and an example that opens the sheet first cannot tell a connect-time assignment from an
  # open-time one - watched passing with both `setAttribute` calls moved into `open`.
  it "has the trigger promise the sheet before it is used" do
    member = create(:member, :owner)
    sign_in_as member.user

    visit group_path(member.group)

    trigger = find("##{dom_id(member.group, :confirm_delete)}_form button")
    expect(trigger["aria-haspopup"]).to eq "dialog"
    expect(trigger["aria-controls"]).to eq dom_id(member.group, :confirm_delete)
  end

  # Asserted where the guard does its work rather than on the restored page. Turbo serves a
  # restored snapshot with no request, so a snapshot cached with `<dialog open>` comes back as a
  # panel nobody opened, outside the top layer where Escape no longer dismisses it. Measured across
  # six runs, `turbo:before-cache` reports `false` with the binding and `true` without it every
  # time, where reading the restored page instead lands between two render cycles.
  it "does not leave the sheet open in the page Turbo caches" do
    member = create(:member, :owner)
    sign_in_as member.user
    arrive_at_the_sheet_through_the_index(member.group)
    record_what_gets_cached

    page.go_back
    expect(page).to have_link "New group"

    expect(page.evaluate_script("window.cachedWithSheetOpen")).to be false
  end

  context "when the destructive control has opened it" do
    let(:member) { create(:member, :owner) }
    let(:group)  { member.group }

    before do
      sign_in_as member.user

      visit group_path(group)
      within("##{dom_id(group, :confirm_delete)}_form") { click_button "Delete group" }
    end

    # `.btn-error` rather than `.modal-box`, for the reason `spec/system/groups_index_spec.rb`
    # states: light `base-100` is `oklch(100% 0 0)`, identical to the surface the matcher
    # composites against, so the box scores 1.0 and reads as painting nothing.
    it "paints the sheet" do
      expect(page).to have_css "dialog[open]"
      expect(page).to paint ".modal-action .btn-error"
    end

    it "has no accessibility violations" do
      expect(page).to be_accessible
    end


    # `be_accessible` does not cover this and was watched passing with `aria-labelledby` removed:
    # axe's `aria-dialog-name` rule is tagged `best-practice`, which is outside the cumulative WCAG
    # tags `spec/support/axe.rb` runs. So the reference is resolved here instead of asserted, which
    # is what makes a dropped attribute, a typo'd id and a moved title all fail.
    it "names the sheet by its title" do
      name = page.evaluate_script(<<~JAVASCRIPT)
        (function() {
          const sheet = document.querySelector("dialog[open]");
          const id = sheet && sheet.getAttribute("aria-labelledby");
          const label = id && document.getElementById(id);
          return label && label.textContent.trim();
        })()
      JAVASCRIPT

      expect(name).to eq "Delete this group?"
    end

    it "keeps the group when the secondary is used" do
      within(".modal-action") { click_button "Keep group" }

      expect(page).to have_no_css "dialog[open]"
      expect(Group.where(id: group.id)).to exist
    end

    it "keeps the group when Escape is pressed" do
      find("dialog[open]").send_keys(:escape)

      expect(page).to have_no_css "dialog[open]"
      expect(Group.where(id: group.id)).to exist
    end

    # A viewport corner rather than the backdrop's centre, which the centred box sits over: the
    # backdrop stretches across the whole modal grid cell and the box shares that cell.
    #
    # Ferrum's mouse rather than `find(...).click(x:, y:)`, which Cuprite delivers as no click at
    # all here - watched, with a listener on the button, reporting an empty event list and the sheet
    # still open, while the same coordinates through the mouse close it. That is what the opening
    # `have_css` pays for: a raw click does no waiting of its own.
    #
    # The marker is what stops this passing for the wrong reason, and it was watched doing exactly
    # that: a backdrop form with no `method="dialog"` submits a GET to the current URL instead, and
    # a sheet gone because Turbo swapped the body satisfies every other assertion here. It goes on
    # the element rather than on `window`, which a Turbo visit leaves standing - watched too.
    it "keeps the group when the backdrop is clicked" do
      expect(page).to have_css "dialog[open]"
      page.execute_script "document.querySelector('dialog').dataset.sameSheet = 'yes'"

      page.driver.browser.mouse.click(x: 4, y: 4)

      expect(page).to have_no_css "dialog[open]"
      expect(page).to have_css "dialog[data-same-sheet='yes']", visible: :all
      expect(Group.where(id: group.id)).to exist
    end

    it "deletes the group and lands on the index when the primary is used" do
      within(".modal-action") { click_button "Delete group" }

      expect(page).to have_current_path groups_path
      expect(Group.where(id: group.id)).not_to exist
    end
  end
end
