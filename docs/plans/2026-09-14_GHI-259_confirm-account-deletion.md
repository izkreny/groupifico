> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Confirm account deletion by typing DELETE

## Which frame this is built from

Frame 9i, read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. It draws the shared sheet with the leave sentence, the block naming the group still owned, a "Type DELETE to confirm" field, Delete my account and Keep my account.

## What the sheet is today

`user_profiles/show.html.erb` renders `shared/confirm_sheet` in its plain variant, with a fixed body ("You leave every group, …"), and the `#solely_owned_groups` alert #289 added sits on the Me screen above it. `UsersController#destroy` redirects to `user_path`, which the destroyed account can never load: its sessions went with it, so the router redirect and the profile's guard bounce it to the sign-in form.

## The type-to-confirm variant

`shared/_confirm_sheet.html.erb` gains two optional locals, `word: nil` and `block: nil`, so the four plain callers are untouched. With a `word`, the sheet draws a labelled text field reading "Type DELETE to confirm" and renders its primary `disabled` in the server's markup; a new `app/javascript/controllers/type_to_confirm_controller.js`, separate from `app/javascript/controllers/dialog_controller.js` so that controller's claim that opening is the only JavaScript the sheet needs stays true, enables the primary only while the field reads exactly the word. It compares once on `connect` as well, so a snapshot Turbo restores with the word already typed agrees with its own button.

The field sits outside every form and carries no `form` attribute, and that is load-bearing: the trigger form's default button is the trigger itself, which is never disabled, so a field associated with that form would submit the delete on Enter without the word ever being checked.

With a `block`, the message renders as its own alert inside the sheet, `aria-describedby` names it alongside the body, and the controller is not wired at all: the primary stays disabled whatever is typed. The server's guard in `User#ensure_no_group_loses_its_only_owner` stays the authority, and the rescue in `UsersController` stays for the paths that still reach it.

## What the sheet says

The body is built by a new `UsersHelper#account_deletion_message(groups)`, beside `solely_owned_groups_message`, which already produces the block's copy word for word. `groups` is `current_groups` without the solely owned ones, which is what 9i draws: the reader who owns Riverside Choir reads "You leave Ninth Street Band", because the group they still own is named in the block beneath. With no such group the leave clause drops and the body reads "Every registration goes with you. This can't be undone."

## The block moves into the sheet

The `#solely_owned_groups` alert leaves the Me screen for the sheet. 9g never drew it, and the reason #254 kept it, that the reader learns why before pressing delete, now holds inside the sheet the reader has to open to delete at all. The comments in `user_profiles/show.html.erb` and `UsersController` that place the explanation on the Me screen are corrected with it.

`spec/requests/user_profiles_spec.rb`'s "lists none of the reader's groups" is scoped to exclude the `<dialog>`: the leave sentence names groups by design, where #254's criterion is about the screen's rows.

## Landing on the sign-in form

Criterion 3 needs the deleted reader to land on the sign-in form with a notice, so `destroy` redirects to `new_session_path` with "Your account was deleted." That is #179's fix, and the known-wrong comment on `spec/requests/user_spec.rb`'s `DELETE /user` example goes with it.

## Without JavaScript

The trigger still submits the delete on the first click without the word, exactly as the plain sheet does today, per `app/javascript/controllers/dialog_controller.js`. The typed word is a guard against a slip, not an authorization, so the server does not check it: a check there would break the no-JavaScript path and protect nothing the model's guard does not.

## The system spec

`spec/system/account_deletion_refusal_spec.rb` becomes `spec/system/account_deletion_spec.rb`, because it now covers the whole deletion flow and not only its refusal, and `spec/system/me_spec.rb`'s header points at the new name. Its "paints the alert when the sheet is confirmed" example cannot run once the primary is disabled while a group is owned, so it is replaced by one where the block stops being true in between: a co-owner is present when the sheet renders and leaves before DELETE is pressed, which is the one browser path that still reaches the refusal's alert.

## Steps

- Add `UsersHelper#account_deletion_message` with its examples in `spec/helpers/users_helper_spec.rb`: one group, several, and none.
- Point `UsersController#destroy` at `new_session_path` with its notice, and update `spec/requests/user_spec.rb`: both success examples assert the new target and the notice, and the known-wrong comment goes.
- Add the `word` and `block` locals to `shared/_confirm_sheet.html.erb` and `type_to_confirm_controller.js`, through the daisyUI Blueprint MCP server.
- Render the type-to-confirm sheet from `user_profiles/show.html.erb` with the leave sentence and, when the reader still owns a group alone, the block, moving `#solely_owned_groups` off the screen; extend `spec/requests/user_profiles_spec.rb` for the sentence, the block and the disabled primary, and scope the groups-not-listed assertion outside the `<dialog>`.
- Rename the refusal system spec to `spec/system/account_deletion_spec.rb` and extend it: the sheet paints and has no accessibility violations; the primary stays disabled on "delete" and enables on "DELETE"; pressing it deletes the account and paints the sign-in form's notice; Keep my account closes the sheet and keeps the account; while a group is owned the block paints and the primary stays disabled after DELETE; the refusal's alert paints when the block arrives between render and press; and the open sheet fits a phone's width. Repoint `spec/system/me_spec.rb`'s header and its overflow example's wait.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards. The field's markup and the block's alert are the syntax expert's to settle rather than guessed here.

## Verification

- `bin/ci` is green
- `bin/rspec spec/system/account_deletion_spec.rb spec/system/me_spec.rb spec/system/confirm_sheet_spec.rb` passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether a disabled primary reads as waiting for the word rather than broken, and whether the block reads as the reason it is disabled, in both themes.

## Open questions

- Whether this pull request also closes #179. Criterion 3 makes this branch do #179's whole fix, and #179 carries no milestone, so closing it here is a tracker call this plan does not make: the body carries `Closes #259` alone until it is answered.

## Settled

None yet.
