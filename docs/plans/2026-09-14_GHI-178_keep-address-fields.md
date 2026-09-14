> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Keep the address fields on a failed save

## When the fields actually go missing

`Event` rejects a nested address whose values are all empty (`accepts_nested_attributes_for :address, reject_if:`), so what a failed save loses depends on what was submitted. An address the reader typed is built by the nested attributes and comes back on the re-render already. An address left blank is rejected, `@event.address` stays nil, and `_form.html.erb` draws the "Create new address:" heading over zero `event[address_attributes][...]` inputs, so the reader has no way to type one on the retry. That is the case the issue's fix closes, and it is also the case the existing invalid-event examples already submit: `{ name: "" }` with no address parameters.

## The fix

`EventsController#create` and `#update` build the address in their failure branches, spelled exactly as `#edit` and `#duplicate` already spell it: `@event.build_address unless @event.address`. The guard matters in `#create`, where a typed address is already built and must not be replaced by an empty one.

Every render of `events/_form` then holds an address object: `#new` builds one unconditionally, `#duplicate` and `#edit` build one when absent, and the two failure branches now do too. So both `event.address&.persisted?` calls in `app/views/events/_form.html.erb` go back to a plain `event.address.persisted?`. That change alters no behaviour once the controller fix is in, so it lands as its own `refactor:` commit after the fix, per the one-kind-per-commit rule in `.agents/testing.md`.

## The specs

The two existing examples "re-renders the new page when the event is invalid" and "re-renders the edit page when the event is invalid" in `spec/requests/events_spec.rb` each gain one assertion, `expect(response.body).to include "event_address_attributes_name"`, and their descriptions say the address fields come back. The fields are a facet of what the re-render contains, so extending the examples beats adding new ones, and both stay well under `RSpec/MultipleExpectations`' ceiling. The `:event` factory attaches no address, so the update example starts from an event without one, which is the state that reproduces the bug.

A third example submits an invalid event with a typed address name to `create` and asserts the typed value comes back. That behaviour already holds today, so this example cannot be watched failing on the pre-fix code; it is there because the fix's `unless` guard is what keeps it true, and deleting the guard is the mutation it catches.

The issue's note about an exception to #149's no-HTML-assertions rule no longer applies: `.agents/testing.md` now has request specs assert the key HTML, and the file already does throughout.

No system spec: this is controller behaviour, and #253, which rebuilds this form, owns its browser coverage.

## Steps

- Extend the two invalid-event examples with the address-fields assertion and add the typed-address example, then run `bin/rspec spec/requests/events_spec.rb` and watch the two extended examples fail.
- Build the address in the failure branches of `EventsController#create` and `#update`, and watch the three examples pass; commit as `fix:`.
- Drop both `&.` guards in `app/views/events/_form.html.erb`; commit as `refactor:`.
- Run `bin/ci`.

## Verification

- `bin/rspec spec/requests/events_spec.rb` passes, with the two extended examples watched failing before the fix
- `bin/ci` is green

These gates prove the fields render on a failed save; none of them checks that the retry then saves the typed address, which the nested attributes already do on any submission and nothing here changes.
