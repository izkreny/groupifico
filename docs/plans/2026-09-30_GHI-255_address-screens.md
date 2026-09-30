> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the address screens

## Which frames this is built from

Frames 9k (One place) and 9l (Correct place), read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. The issue outranks the frames where the two differ.

## What the screens are today

`addresses/show` and `addresses/edit` are the scaffold's: an `h1`, `addresses/_address` listing all nine columns down to the coordinates, and ghost links to an `addresses/index` that nothing in the application links to. `addresses/_form` wraps `addresses/_form_fields`, which draws the same nine columns and is #239's, so it is left alone; the event form's New address… is its other caller.

## Show: "Place"

`shared/page_header` with "Place", then the name at `text-record` in the same row as "Correct", the way `events/_event` puts Edit beside the event's name. "Correct" is gated on `allowed_to?(:update?, @address)`, which for a group's home address is the owner's alone. The street line is a link to `AddressesHelper#address_map_url`, the helper every address link in the app already uses, followed by the postcode and city line and the country. Where a group calls the address home, "<Group> · home address" follows; then "Used by", each event linking to its detail with `event_schedule_start` beside it, earliest first.

## Edit: "Correct place"

`shared/page_header` with "Correct place", then the five fields the issue names, drawn in `addresses/_form` itself rather than through `_form_fields`: Name with the hint "As it reads on cards", Street and number as one pair over the `street_name` and `building_number` columns, Postcode, City and Country. The note "Used by N events in <group>. They all move with it." sits under them, and Cancel back to the show screen and Save close the form, as on the group and event forms. The labels go under `activerecord.attributes.address` in `config/locales/en.yml`, so an error message names the field the reader sees; that reaches the same columns on the group and event forms too, which is the one field set the design asks for.

The group the note names is the one the address belongs to: the group that calls it home, or else the group of the events using it. Every owner of an address belongs to one group, per `AddressPolicy`'s own comment, so one `Address` method answers it for both screens.

## Removing the index

Nothing links to `addresses_path`, so the index goes with its route, its action, its view, `AddressPolicy#index?` and the `relation_scope` only the action used. The request examples for it become one asserting the route is gone, as the file already does for `new` and `destroy`, and the policy spec loses the rule and the scope examples. The routes comment gains the reason, and `docs/AUTHORIZATION.md` needs nothing: its read row is `show?`'s.

## Steps

- Name the address's attributes in `config/locales/en.yml`.
- Add the `Address` method that names the group an address belongs to, with model examples in `spec/models/address_spec.rb`.
- Rebuild `addresses/show.html.erb` and `addresses/_address.html.erb` as *Show* above says.
- Rebuild `addresses/edit.html.erb` and `addresses/_form.html.erb` as *Edit* above says.
- Remove the index as *Removing the index* says: `app/views/addresses/index.html.erb` (delete), the route, the action, the policy rule and scope, and their examples in `spec/requests/addresses_spec.rb` and `spec/policies/address_policy_spec.rb`.
- Update the request examples that assert the old markup, and add ones for the home-address line, the Used by list, Correct absent for a reader refused `update?`, no delete control on either screen, the five fields with their hint, and the note.
- Extend `spec/system/address_edit_page_spec.rb` for what only a browser adds: Correct paints and lands on the edit screen, Cancel and Save land back on the show screen, and both screens have no accessibility violations.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards.

## Verification

- `bin/ci` is green, or red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land
- `bin/rspec spec/system/address_edit_page_spec.rb` passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether a reader arriving from the event form in a new tab knows how to get back to it.

## Settled

- The country is shown and edited as the stored `country_code`, since the column holds a code and nothing in the application names countries; the frame's "Croatia" is sample data rather than copy.
- 9k's note under Used by is not drawn: the issue's criteria leave it out of the show screen and put it on the edit screen, where the correction happens.
- An address no event uses draws no Used by section, and its edit screen no note, since "Used by 0 events … They all move with it" says nothing true.
- Save sits under the form beside Cancel rather than in the header, as on the group and event forms, which is where the redesigned screens put a form's submit.
- The system-spec gate takes the same exception as `bin/ci`: red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which the file's pre-existing rejected-save example meets on `main` too.
