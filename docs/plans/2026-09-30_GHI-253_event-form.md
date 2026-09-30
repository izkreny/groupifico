> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the event form

## Which frames this is built from

Frames 4e (New event), 4f (Duplicate event) and 4k (Edit event), read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. The three share one form and differ in the title, the note under it, and the buttons.

The issue outranks the frames where the two differ. It trims the time hint to "Typed and shown in Europe/Zagreb", so the frame's "the one application zone; stored UTC" is not drawn; the frames' annotations under Status and Where are notes to the designer, not copy, and are not drawn either. The duplicate note is the issue's two sentences, without the frame's third. The frames' button labels are kept, since the issue says nothing about them: "Create event", "Create copy", "Save changes", and Cancel on all three.

## What the form is today

`events/_form` draws every attribute through `AppFormBuilder#field`: status and category as selects, the manager as a select of every member, and the address as a select shown only when the group has addresses, followed by either an edit link for a saved address or `addresses/_form_fields` for a new one. `new` and `edit` wrap it in the scaffold's `h1` and ghost links, and `duplicate` renders `new` after replacing `@event` with the copy, so nothing on that screen can say what was copied.

## The Where picker, and the two writes it must not make

Each of the group's addresses becomes a radio row, "<name> — <street>", followed by "New address…", which unfolds `addresses/_form_fields` with a `peer-checked:` sibling rule rather than a controller. Those fields are in the page whichever row is picked, so they post whichever row is picked, and `accepts_nested_attributes_for` builds a new address from them that replaces the pick. Today's `edit` makes that worse: `fields_for :address` renders the event's saved address, so once the fields are always drawn, every plain Save would clone it.

So the plan changes two things the issue's ownership list does not name. The nested fields are always drawn for a fresh address, or for the event's own unsaved one after a refused save, which is what keeps the typed values; and `EventsController#event_params` drops `address_attributes` whenever an `address_id` arrives, so a picked address is used and never edited here, as the frames say. The controller's comment on the nested attributes is rewritten to match in the same commit.

"Correct it" sits on each row, shown only on the checked one, and only where `allowed_to?(:update?, address)`: `Group#addresses` includes the group's home address, which `AddressPolicy#update?` reserves to the group's owner, and the epic wants a refused control absent. It opens the address's edit screen in a new tab, as today's link does, so the half-typed event is not lost.

## The manager list

The group's active members and "nobody", the blank that `foreign_member?` lets through for the model to clear. The event's current manager is included even when their membership is no longer active: a `<select>` with no matching option submits its first one, so leaving them out would silently hand the event to somebody else on any save.

## Status, and why the builder changes again

`AppFormBuilder#segmented_field` draws a daisyUI `join` of radio buttons whose face is the choice's name. Status is the same control with a different face: the four legend icons, the picked one also showing its name. That is a variant of the one method rather than a second one, because the fieldset, legend, note slot and `drawn` bookkeeping are identical; it takes an icon per choice, and the markup is the component syntax expert's to settle. Category uses the method unchanged.

## Labels come from the locale

The frame calls `description` Notes, `starts_at` Starts, `ends_at` Ends and `address_id` Where. Passing `label:` would rename the control while `full_messages_for` kept saying "Description is too long", so the names go under `activerecord.attributes.event` in `config/locales/en.yml`, where the label and every error message read them.

## Steps

- Name the event's attributes in `config/locales/en.yml`.
- Teach `AppFormBuilder#segmented_field` the icon face, and cover it in `spec/form_builders/app_form_builder_spec.rb`.
- Add the Where row label and the manager list to `EventsHelper`, reshape `event_statuses` and `event_categories` into the choices the two segmented controls take, and update `spec/helpers/events_helper_spec.rb`; delete `AddressesHelper#address_choices` and `MembersHelper#member_choices` with their examples if a `grep` still finds this form their only caller.
- Rebuild `events/_form.html.erb` in the issue's order, with strict locals for the submit label and the cancel target, and pass them from `app/views/styleguides/show.html.erb`.
- Rebuild `events/new.html.erb` and `events/edit.html.erb` through `shared/page_header`, "New event" and "Edit event"; `edit` ends with `shared/confirm_sheet` in its plain variant, gated on `allowed_to?(:destroy?, @event)`, below the form rather than in its button row, since a `button_to` cannot sit inside a form.
- Add `events/duplicate.html.erb` (new), titled "Duplicate event" with the copy note, and have `EventsController#duplicate` keep the source event for it and render its own template.
- Change `EventsController#event_params` and the `fields_for` object as *The Where picker* above says, with request examples in `spec/requests/events_spec.rb` for a pick with filled nested fields, a plain Save on an event with an address, and a refused save keeping every typed value.
- Update the request examples that assert the old markup, and add ones for the manager list, the per-row Correct it and the Delete control.
- Add `spec/system/event_form_spec.rb` (new) for what only a browser adds: the segmented controls paint and answer to a click, New address… unfolds its fields, Correct it and Cancel land where they point, Delete lands on the events list, and every screen has no accessibility violations.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards.

## Verification

- `bin/ci` is green
- `bin/rspec spec/system/event_form_spec.rb` (new) passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether the status accordion reads as one control rather than four icons, and whether "<name> — <street>" says enough to pick the right place.

## Settled

- The issue's overview says the duplicate screen offers quick shifts; its criteria and technical notes say the frames no longer draw them. The criteria win, and none are built.
- The system spec is a new file rather than an extension, because no file covers the form's own view; `spec/system/event_detail_spec.rb` keeps the pencil flow that lands on it.
- A refused create from the duplicate screen re-renders `new`, so the copy note and "Create copy" give way to "New event". `create` has no source event to name, and carrying one through a hidden field is more machinery than a refusal is worth.
- Delete on `edit` does not remove Delete from the event detail; frame 4k says both screens keep it.
