require "rails_helper"

# One file for the three screens, because new, duplicate and edit render one `events/_form` and
# differ only in what surrounds it.
#
# Only what a browser adds. Which fields the form draws and in what words, which address is
# picked, who is offered Correct it and Delete, what a refused save keeps and what the duplicate
# note says are all `spec/requests/events_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left: that the status icons paint as
# one control whose picked segment names itself, that New address unfolds its fields, and that
# Correct it, Cancel and Delete land where they say.
RSpec.describe "The event form", type: :system do
  include ActionView::RecordIdentifier

  it "paints the new event screen in light, with no accessibility violations" do
    actor = create(:member, :active, :events_administrator)
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_group_event_path(actor.group)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".join label.btn:has(input:checked)"
    expect(page).to paint ".join input.btn:checked"
    expect(page).to be_accessible
  end

  it "paints the new event screen in dark, with no accessibility violations" do
    actor = create(:member, :active, :events_administrator)
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_group_event_path(actor.group)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".join label.btn:has(input:checked)"
    expect(page).to paint ".join input.btn:checked"
    expect(page).to be_accessible
  end

  # A saved address is what draws a Where row, its checked radio and its Correct it link, and no
  # factory gives an event one, so these are the audits that reach the picker's rows.
  it "paints the edit screen with a saved address in light, with no accessibility violations" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group, address: create(:address, name: "Studio B"))
    sign_in_as actor.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit edit_group_event_path(event.group, event)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to have_link "Correct it"
    expect(page).to be_accessible
  end

  it "paints the edit screen with a saved address in dark, with no accessibility violations" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group, address: create(:address, name: "Studio B"))
    sign_in_as actor.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit edit_group_event_path(event.group, event)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to have_link "Correct it"
    expect(page).to be_accessible
  end

  # daisyUI colours a checked radio drawn as a button, and the icon segment is a label around a
  # hidden radio, so its colour is carried up by `has-checked:` alone. `paint` cannot see it go
  # missing: an unpicked segment paints too, only in the base colour. The category control is
  # daisyUI's own radio button, so it is the colour a picked segment has to match.
  it "colours the picked status segment the way daisyUI colours the picked category" do
    actor = create(:member, :active, :events_administrator)
    sign_in_as actor.user

    visit new_group_event_path(actor.group)
    colours = page.evaluate_script(<<~JAVASCRIPT)
      [ ".join label.btn:has(input:checked)", ".join input.btn:checked", ".join label.btn:has(input:not(:checked))" ]
        .map(selector => getComputedStyle(document.querySelector(selector)).backgroundColor)
    JAVASCRIPT

    expect(colours[0]).to eq colours[1]
    expect(colours[0]).not_to eq colours[2]
  end

  it "keeps the new event screen inside a phone's width" do
    actor = create(:member, :active, :events_administrator)
    sign_in_as actor.user
    resize_to ViewportHelper::MOBILE

    visit new_group_event_path(actor.group)

    expect(page).to have_css "#event_ends_at_hint"
    expect(horizontal_overflow).to eq 0
  end

  it "paints the duplicate screen's note, with no accessibility violations" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit duplicate_group_event_path(event.group, event)

    expect(page).to paint "[role=status].alert"
    expect(page).to be_accessible
  end

  # The name is hidden on every segment but the picked one, so which word shows is a fact about
  # the rendered page, and the saved status is what makes it a fact about the form.
  it "names the status segment the reader picks, and saves it" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group, status: :unconfirmed)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    find(".join label.btn:has(input[value='confirmed'])").click

    expect(page).to have_css ".join label.btn span", text: "Confirmed", visible: :visible
    expect(page).to have_no_css ".join label.btn span", text: "Unconfirmed", visible: :visible
    click_button "Save changes"

    expect(page).to have_current_path group_event_path(event.group, event)
    expect(event.reload.status).to eq "confirmed"
  end

  it "unfolds the new-address fields when New address is picked, and saves with them" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    expect(page).to have_field "event_address_attributes_name", visible: :hidden
    choose "New address…"
    fill_in "event_address_attributes_name", with: "Village Hall"
    click_button "Save changes"

    expect(page).to have_current_path group_event_path(event.group, event)
  end

  it "shows the typed new address again when the save is refused" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    fill_in "event_name", with: ""
    choose "New address…"
    fill_in "event_address_attributes_name", with: "Village Hall"
    click_button "Save changes"

    expect(page).to have_css "#event_name_error"
    expect(page).to have_field "event_address_attributes_name", with: "Village Hall"
  end

  it "opens the picked address's own form from Correct it" do
    actor = create(:member, :active, :events_administrator)
    venue = create(:address, name: "Studio B")
    event = create(:event, group: actor.group, address: venue)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    correction = window_opened_by { click_link "Correct it" }

    within_window(correction) { expect(page).to have_current_path edit_address_path(venue) }
  end

  it "returns to the events list when the new event screen is cancelled" do
    actor = create(:member, :active, :events_administrator)
    sign_in_as actor.user

    visit new_group_event_path(actor.group)
    click_link "Cancel"

    expect(page).to have_current_path group_events_path(actor.group)
  end

  it "returns to the event when the edit screen is cancelled" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    click_link "Cancel"

    expect(page).to have_current_path group_event_path(event.group, event)
  end

  it "lands on the events list once Delete is confirmed" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    within("##{dom_id(event, :confirm_delete)}_form") { click_button "Delete event" }
    within("dialog[open]") { click_button "Delete event" }

    expect(page).to have_current_path group_events_path(event.group)
    expect(Event.exists?(event.id)).to be false
  end
end
