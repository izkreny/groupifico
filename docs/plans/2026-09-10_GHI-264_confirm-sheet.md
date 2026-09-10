> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Build the confirm sheet

Implementation plan for [#264](https://github.com/izkreny/groupifico/issues/264). The issue holds the acceptance criteria; this answers how.

## Approach

`shared/_confirm_sheet` renders one unit: the destructive control and the `<dialog>` it opens, wrapped in a single `data-controller="dialog"` element. The control is an ordinary `button_to ... method: :delete` form, so with JavaScript off it is a plain confirm-less submit exactly as today's `turbo_confirm` degrades. With JavaScript on, `dialog#open` intercepts that form's `submit`, cancels it and calls `showModal()` on the sheet. The sheet's primary is a `<button form="...">` naming that same form, which HTML makes the form's owner regardless of where it sits in the DOM, so the delete posts through one form with one CSRF token rather than two copies of the same form.

The control and the sheet ship together rather than separately because a Stimulus action only reaches a controller on its own element or an ancestor. A control rendered by the calling screen, outside the sheet's subtree, cannot open it without a second controller or a `document.querySelector` reaching across the page - and repeating that wiring on four screens is the duplication this issue exists to remove. So each screen renders one line and gets both halves; the control names the sheet through the `id:` local, which the partial also uses for the form id and the title and body ids.

Four screens render it: the group, event and member show pages, and the account. That is the set the issue names, and #259 replaces the account's plain body with frame 9i's typed word and owner block on top of the same partial. `registrations/show` and the `Destroy` buttons on the four index pages stay on `turbo_confirm`; they are outside the four the issue names, and the screens that own them are redesigned by their own issues.

## What closes the sheet, and why no `close` action

The issue's technical notes ask for `open` and `close` actions. Only `open` is written, because every close AC1 requires is already native and a `close` action would have no caller:

- **The secondary** is a `<button>` inside a `<form method="dialog">`, which closes the dialog natively.
- **Escape** is native to a dialog opened with `showModal()`.
- **The backdrop** is daisyUI's `modal-backdrop`, itself a `<form method="dialog">` covering the area outside the box.

The load-bearing fact is that Turbo leaves those forms alone, and it was read rather than recalled: in the installed turbo-rails 2.0.23, `submitBubbled` tests the form's `method` (or the submitter's `formmethod`) against `"dialog"` and returns without intercepting when it matches. So a `method="dialog"` submit reaches the browser and closes the dialog instead of becoming a Turbo request.

The controller does keep one listener beyond `open`: `turbo:before-cache` closes the sheet. On confirm the delete redirects while the sheet is open, so Turbo caches a snapshot carrying `<dialog open>`, and a back navigation would restore it as a non-modal open panel over the page.

`open` also has to ignore the confirm button's submit, which bubbles out of the same form it is bound to. It returns early when the sheet is already open, which is one line and needs no reference to the button.

## Copy

Frame 9i is the only confirm sheet drawn in the wireframes, and it is the account's type-to-confirm variant; frame 7's coverage note says the group, event and member deletes use the same sheet as a plain confirm, without drawing their copy. So each screen's title, body and labels are derived from 9i's shape - a question, a consequence, a `Delete …` primary and a `Keep …` secondary - and the consequence is read off the models' `dependent:` declarations rather than guessed:

| Screen  | Title                  | Consequence read from                                             | Primary             | Secondary         |
|---------|------------------------|-------------------------------------------------------------------|---------------------|-------------------|
| Group   | `Delete this group?`   | `Group` destroys members and events, events destroy registrations | `Delete group`      | `Keep group`      |
| Event   | `Delete this event?`   | `Event` destroys registrations                                    | `Delete event`      | `Keep event`      |
| Member  | `Remove this member?`  | `Member` destroys registrations and roles                         | `Remove member`     | `Keep member`     |
| Account | `Delete your account?` | `User` destroys its profile, sessions and memberships             | `Delete my account` | `Keep my account` |

The account's title and labels are frame 9i's own. Its body drops 9i's group name and owner block, both of which belong to #259: the frame writes for a reader with one group, and its owner block is flagged in the export as ahead of the backend, with no last-owner guard on `DELETE /user`.

The four triggers are relabelled from the scaffold's `Destroy this group` to the sheet's own verb, because a control that opens a sheet saying `Delete group` cannot itself say `Destroy`. Frames 4k and 3d shorten theirs further, to an icon-width `Delete` and `Remove` carrying an aria-label; that is part of redesigning those screens and belongs to #253 and #249.

## Placement

`modal-bottom sm:modal-middle`, both stock daisyUI classes. Frame 9i draws the sheet pinned to the bottom of the phone artboard, and a sheet rather than a centred box is the pattern the frame settles rather than a styling value it happens to carry, so `## Wireframe fidelity` does not send it back to the plain default. No custom CSS and no arbitrary-value utility is written either way.

## Accessibility

The `<dialog>` takes `aria-labelledby` pointing at its title and `aria-describedby` pointing at its body line, so the sheet has an accessible name and its consequence is announced with it. `be_accessible` fails on the missing name, which is what makes this checkable rather than asserted.

## Steps

- Compose the sheet's markup through the daisyUI Blueprint MCP server, loading the local `daisyui-blueprint-mcp` skill first per the epic: setup expert, rules enforcer, component syntax expert for `modal`, then the quality inspector on the finished change.
- Add `app/views/shared/_confirm_sheet.html.erb` with strict locals `(id:, url:, title:, body:, trigger:, confirm:, dismiss:)`, reading no instance variable: the wrapper carrying `data-controller="dialog"`, the `button_to` delete form, and the `<dialog>` with its title, body, primary `<button form=…>`, secondary and backdrop.
- Add `app/javascript/controllers/dialog_controller.js`: `open` cancelling the trigger form's submit and calling `showModal()`, returning early when the sheet is already open, plus the `turbo:before-cache` close.
- Replace the `button_to` in `groups/show`, `events/show`, `members/show` and `users/show` with one `render "shared/confirm_sheet"` each, passing the copy from the table above.
- Add `spec/system/confirm_sheet_spec.rb` on the group show page: the sheet paints when opened, each of the three dismissals leaves the group in place, confirming redirects to the index with the group gone, and the open sheet has no accessibility violations.
- Add one example to `spec/requests/groups_spec.rb` asserting the show page's delete form carries `_method=delete` with the trigger as its own submit button, which is the half of the no-JavaScript degradation a request spec can see.

## Verification

- [ ] `bin/ci`

What those gates cannot see: whether the derived copy reads right, since only the account's is drawn; whether the bottom sheet sits where the owner wants it on a phone; and the no-JavaScript path end to end, which no driver in this suite can run with scripting off. The request spec asserts the markup that makes that path work, not the path.

The system spec is watched failing before the partial exists, and each dismissal is watched failing against a sheet whose secondary submits the delete - a `method="dialog"` typo away - so "nothing was deleted" is seen red rather than assumed. The `be_accessible` example is watched failing against the dialog with `aria-labelledby` removed.

## Open questions

None.

## Settled

None yet.
