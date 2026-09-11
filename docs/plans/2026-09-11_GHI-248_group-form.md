> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the group form

## Which frames this is built from

Frames 2e (New group, `GET /groups/new`) and 2f (Edit group, `GET /groups/:id/edit`), read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry.

The issue outranks the frames wherever the two say different things, and they do so three times: the frame's hint under the type control reads "The exception: a second group can be any type. Your first group took its type from the hostname (9b)." where the issue fixes the copy as "Your first group took its type from the hostname; a second group can be any type."; the frame puts Delete group in the same row as Cancel and Save changes where the issue's overview has it alone at the bottom; and the frame's address card carries a trash beside the pencil where the issue names the pencil alone. Each is built the issue's way.

## What these two screens are today

Both are the scaffold: an `h1`, `groups/_form`, and a row of ghost links. The form draws Name and Description through `AppFormBuilder#field` and then `fields_for :address` into `addresses/_form_fields`, identically on both screens. `group_type` has no control anywhere, because `Group`'s `before_validation` sets it from `Current.brand` on create.

So the redesign is four things the form cannot do today: a type control on `new`, the same attribute as read-only text on `edit`, an address that is nested fields on `new` and a summary line on `edit`, and a delete that only `edit` carries.

## The type control, and why it goes through the form builder

`AppFormBuilder#field` draws a label, a control, and one note slot that is the hint or the error; it also records the attribute in `drawn`, which is what keeps a message out of the summary in `shared/_errors`. A segmented radio group cannot go down the `as:` path, because that path draws a `<label for>` pointing at a single control and `control` dispatches to one field helper. It gets a sibling method instead, `segmented_field`, drawing a `<fieldset>` with a `<legend>`, a daisyUI `join` of radio buttons, and the same `note_tag` and `drawn` bookkeeping.

One caller justifies it because the alternative is not smaller: writing the radios in `groups/_form` duplicates the label, hint and error anatomy the builder exists to own, and leaves `group_type` unregistered so its message lands in the summary while the control it belongs to sits unmarked.

That registration is a behaviour change with a spec attached to it. `spec/requests/groups_spec.rb`'s "names an error whose attribute the form draws no field for" uses `group_type` as its example precisely because the form drew nothing for it. Once the control exists the message attaches to the control, so the example asserts that instead, and the comment in `AppFormBuilder#unattached_error_messages` naming `Group#group_type` is corrected in the same commit. `spec/form_builders/app_form_builder_spec.rb` renders its own form and keeps its `group_type` example unchanged.

## The back chevron on a group-less pushed screen

`/groups/new` is the only pushed screen outside a group, and the shell draws it no chevron today: the layout asks for one only `if group && pushed_screen?`, and `@group` there is unsaved. Dropping that guard alone is wrong, because `pushed_screen?` already answers true on `groups#index`, which would then get a chevron pointing at itself. It is masked today by the same nil group.

So both helpers take the group. `SECTION_ROOTS[:home]` stays `groups#show`, the root of a group's home section, and a second constant names `groups#index` as the root when there is no group; `section_root_path` answers `groups_path` for `:home` without one. `groups#create` re-rendering `new` and `groups#update` re-rendering `edit` both fall out correctly, since the first has no persisted group and the second has one.

## Steps

- Teach `ApplicationHelper#pushed_screen?` and `#section_root_path` the group-less home section, pass the group to both from `layouts/application`, and extend `spec/helpers/application_helper_spec.rb` with the `groups#new` and `groups#index` cases.
- Add `AppFormBuilder#segmented_field`, correct the `unattached_error_messages` comment, and cover the new method in `spec/form_builders/app_form_builder_spec.rb`.
- Add `AddressesHelper#address_summary`, the street, postcode and city of a persisted address as one line, with a helper spec.
- Rebuild `groups/_form.html.erb`: Name, the type as a segmented control on a new group and as read-only text on a persisted one, Description, and a "Where you meet" block that draws Name, Street and number and City on a group whose address is unsaved and the summary with its pencil when it is persisted.
- Rebuild `groups/new.html.erb`: the "New group" title row through `shared/page_header`, the form, and Cancel to the groups index.
- Rebuild `groups/edit.html.erb`: the form, Cancel to the group home, and `shared/confirm_sheet` for Delete group below it, gated on `allowed_to?(:destroy?, @group)`.
- Preselect the type in `GroupsController#new`, `Group.new(group_type: Current.brand.group_type)`.
- Re-point the unattached-error example in `spec/requests/groups_spec.rb`, and add the request assertions for the type control, the read-only type, the address summary and the delete control.
- Add `spec/system/group_form_spec.rb` for what only a browser adds: that the segmented control paints and answers to a click, that a refused create keeps every typed value and reveals the message, that the pencil lands on the address form, that Delete group lands on the groups index, and that both screens have no accessibility violations.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards. The radio-as-button syntax and the read-only field shape are both the syntax expert's to settle rather than guessed here.

## Verification

- `bin/ci` is green
- `bin/rspec spec/system/group_form_spec.rb` passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether the segmented control reads as one control to a person rather than three buttons, and whether the address summary says enough for an owner to recognise the place without opening it.

## Open questions

None.

## Settled

- Which address fields the nested block draws, given that the criterion named five and `addresses/_form_fields` draws nine. It draws Name, Street and number and City; #255 finishes the address screens, and this form does not wait for it.
- Whether Delete group appearing on `edit` while `groups/show` still carries its own is a problem before #247 removes that one. It is not; the duplication is deliberate and `spec/system/confirm_sheet_spec.rb` keeps visiting the group home.
- Whether the submit labels should become "Create group" and "Save changes", which renames the buttons `spec/system/group_refusal_spec.rb` clicks. They should, and that file is updated with them.
