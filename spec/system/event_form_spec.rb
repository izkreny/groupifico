require "rails_helper"

# One file for the three screens, because new, duplicate and edit render one `events/_form` and
# differ only in what surrounds it.
#
# Only what a browser adds. Which fields the form draws and in what words, which address is
# picked, who is offered Correct it and Delete, what a refused save keeps and what the duplicate
# note says are all `spec/requests/events_spec.rb`'s assertions, and per the duplication rule in
# `.agents/testing.md` none of them comes back here. What is left: that the status icons paint as
# one control whose picked segment names itself, that New address unfolds its fields, that filling the list and marking who is on it land their save, and that Correct it, Cancel and Delete land where they say.
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
  it "has no accessibility violations on the edit screen with a saved address, in light" do
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

  it "has no accessibility violations on the edit screen with a saved address, in dark" do
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

  # Who is reserved or requested is `spec/requests/events_spec.rb`'s. That one choice replaces the other is what only a browser's radio group does. The duplicate screen, because filling the list is a new event's choice and the copy arrives with its dates already filled.
  it "takes one way of filling the list, and saves with it picked" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit duplicate_group_event_path(event.group, event)
    choose "Reserve a place for every active member"
    choose "Request response from all active members"

    expect(page).to have_unchecked_field "Reserve a place for every active member"
    click_button "Create copy"

    expect(page).to have_text "Event was successfully created."
    expect(Registration.where(event: actor.group.events.where.not(id: event.id)).pluck(:status).uniq).to eq %w[ response_requested ]
  end

  # WHY: the only place the label a reader picks meets the status it writes, since the request specs post the value themselves.
  it "reserves a place when Reserve is the pick" do
    actor = create(:member, :active, :events_administrator)
    event = create(:event, group: actor.group)
    sign_in_as actor.user

    visit duplicate_group_event_path(event.group, event)
    choose "Not now"
    choose "Reserve a place for every active member"
    click_button "Create copy"

    expect(page).to have_text "Event was successfully created."
    expect(Registration.where(event: actor.group.events.where.not(id: event.id)).pluck(:status).uniq).to eq %w[ reserved ]
  end

  # Who lands on the list is `spec/requests/events_spec.rb`'s. That a press marks a row without saving and a second press unmarks it is what only a browser does.
  it "marks a member taken off without saving, and unmarks them on a second press" do
    actor = create(:member, :active, :events_administrator)
    event, leaving, = event_to_edit_the_list_of(actor)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    press "Remove", leaving

    expect(page).to have_text "will be removed"
    expect(event.registrations.pluck(:member_id)).to eq [ leaving.id ]
    press "Remove", leaving
    expect(page).to have_no_text "will be removed"
  end

  it "saves what is marked with the event" do
    actor = create(:member, :active, :events_administrator)
    event, leaving, arriving = event_to_edit_the_list_of(actor)
    sign_in_as actor.user

    visit edit_group_event_path(event.group, event)
    press "Remove", leaving
    press "Add", arriving
    click_button "Save changes"

    expect(page).to have_text "Event was successfully updated."
    expect(event.registrations.pluck(:member_id)).to eq [ arriving.id ]
  end

  it "paints a pressed + and a pressed trash, with no accessibility violations, in light" do
    actor = create(:member, :active, :events_administrator)
    event, leaving, arriving = event_to_edit_the_list_of(actor)
    sign_in_as actor.user
    prefer_colour_scheme :light

    visit edit_group_event_path(event.group, event)
    press "Remove", leaving
    press "Add", arriving

    expect(page).to paint "label.btn:has(input[name='removing_ids[]']:checked)"
    expect(page).to paint "label.btn:has(input[name='adding_ids[]']:checked)"
    expect(page).to be_accessible
  end

  it "paints a pressed + and a pressed trash, with no accessibility violations, in dark" do
    actor = create(:member, :active, :events_administrator)
    event, leaving, arriving = event_to_edit_the_list_of(actor)
    sign_in_as actor.user
    prefer_colour_scheme :dark

    visit edit_group_event_path(event.group, event)
    press "Remove", leaving
    press "Add", arriving

    expect(page).to paint "label.btn:has(input[name='removing_ids[]']:checked)"
    expect(page).to paint "label.btn:has(input[name='adding_ids[]']:checked)"
    expect(page).to be_accessible
  end

  # WHY: axe does not measure a boundary, and an unpicked radio is nothing but its outline.
  it "draws an unpicked radio's outline at 3:1 in light" do
    event = event_at_a_saved_address
    sign_in_as event.creator.user
    prefer_colour_scheme :light

    visit edit_group_event_path(event.group, event)

    expect(border_contrast("input.radio:not(:checked)")).to be >= ContrastHelper::WCAG_NON_TEXT
  end

  it "draws an unpicked radio's outline at 3:1 in dark" do
    event = event_at_a_saved_address
    sign_in_as event.creator.user
    prefer_colour_scheme :dark

    visit edit_group_event_path(event.group, event)

    expect(border_contrast("input.radio:not(:checked)")).to be >= ContrastHelper::WCAG_NON_TEXT
  end

  # WHY: the outline rule draws a line only for what is not picked, and daisyUI's full ink is what ties a picked radio's ring to its dot.
  it "leaves a picked radio's outline in full ink" do
    event = event_at_a_saved_address
    sign_in_as event.creator.user
    prefer_colour_scheme :light

    visit edit_group_event_path(event.group, event)

    expect(border_contrast("input.radio:checked")).to eq text_contrast("input.radio:checked")
  end

  # WHY: `.radio:focus-visible` and an outline rule written as `.radio:not(:checked)` tie on specificity, so the later one would take the focus border away. Nothing is picked on a new event and the new-address fields are hidden, so Shift+Tab from the description lands on the last Where row. Ferrum's keyboard rather than `send_keys`, which clicks its element first and would pick the radio. The style matcher retries, which waits out daisyUI's border transition.
  it "keeps a focused unpicked radio's border in primary" do
    event = event_at_a_saved_address
    sign_in_as event.creator.user
    prefer_colour_scheme :light

    visit new_group_event_path(event.group)
    find_by_id("event_description").click
    page.driver.browser.keyboard.type([ :shift, :tab ])

    expect(page).to have_css "input.radio:focus-visible:not(:checked)", style: { "border-top-width" => "2px", "border-top-color" => "rgb(140, 73, 26)" }
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
    find("button[form='#{dom_id(event, :confirm_delete)}_form']").click
    within("dialog[open]") { click_button "Delete event" }

    expect(page).to have_current_path group_events_path(event.group)
    expect(Event.exists?(event.id)).to be false
  end

  private
    # An event with one member on its list and one active member off it, in the actor's group.
    def event_to_edit_the_list_of(actor)
      event = create(:event, group: actor.group)
      leaving = create(:registration, event:, member: create(:member, :active, group: event.group)).member
      [ event, leaving, create(:member, :active, group: event.group) ]
    end

    # The list's buttons are labels around a visually hidden checkbox, which carries the name.
    def press(verb, member)
      find("label:has(input[aria-label='#{verb} #{member.full_name}'])").click
    end

    def event_at_a_saved_address
      actor = create(:member, :active, :events_administrator)

      create(:event, group: actor.group, creator: actor, address: create(:address, name: "Studio B"))
    end
end
