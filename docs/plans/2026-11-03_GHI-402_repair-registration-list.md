> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: repair the event's registration list (#402)

The acceptance criteria live on #402 and the design decisions behind them were settled with the owner before this plan; the plan only says how.

## The order

`Event#roster` takes `order:`, `"name"` by default and `"status"` for today's grouping, and sorts by the lowercased `full_name` alone for the first. The values are picked from literals, so a cookie's content never names a sort.

`Events::RosterOrdersController#update`, in `app/controllers/events/roster_orders_controller.rb` (new), routed as `resource :roster_order, only: :update` beside the event's other list resources, authorizes `show?` on the event, writes `cookies.permanent[:roster_order]` from a posted `order` that `presence_in` admits, and answers with `redirect_back_or_to` the event, as the pill controllers do. A GET writes nothing, so the headers are `button_to` forms. `EventsHelper#roster_order` reads the cookie for `events/_roster`, falling back to `"name"`.

## The table

`app/views/events/_roster.html.erb` turns its daisyUI `list` into a daisyUI `table` with a `thead` of "Member" and "Status". Each header is a `button_to` the order controller, carrying one new legend meaning, `sort: "arrows-up-down"` in `IconsHelper::ICONS`, at `size-icon-inline` with `gap-x-icon-text`. The active header is in the page ink with `aria-sort="ascending"` on its `th`, the other in `text-icon-muted`. The row cells keep today's control strip unchanged, and "Edit the list" leaves the button row below the table.

## The edit form

`app/views/events/_form.html.erb` draws "Fill the list" only for a new record, so new and duplicate keep it, and draws a new "Who's on the list" fieldset only for a persisted one, to the reader the registering row admits. It lists the roster's members by name, then the group's active members off the list, then the paused ones with "paused · can't be added" and no button.

Each button is a checkbox drawn as a daisyUI `btn btn-square`: a visually hidden input inside its label, so it stays focusable and posts with the event. Off-list rows post `adding_ids[]` behind a `+`; on-list rows post `removing_ids[]` behind the legend's `delete` trash. A checked box is the pressed state, and the row marks itself with `has-checked:` utilities, struck through for a removal and tinted for an arrival, with "will be added" or "will be removed" as the line under the name. A reader who may not remove gets the trash disabled and "only an administrator can remove". Ids carry the form's `namespace`, because the styleguide draws this form once per theme.

Explicit `adding_ids` and `removing_ids` replace the tick-diff `listed_ids` guard: a row registered while the form sat open was never drawn as removable, so it cannot be removed unseen, and an arrival registered meanwhile is dropped by intersecting with `without_registration_for`, as today.

## The save

`EventsController#update` checks `create?` on the registering row when an arrival is posted and `destroy?` when a removal is, before anything is assigned, which replaces `authorize_reservation!`'s `list_filling` test on this action. It then updates the event and the list in one transaction through `Event#update_roster`, so a refused event save leaves the list alone, and a refused save re-renders the edit form with the posted marks still pressed. `ActiveRecord::RecordNotUnique` is rescued as `Events::RostersController` rescues it today, re-rendering with its moved-on alert.

## What goes

`Events::RostersController`, its route, `app/views/events/rosters/edit.html.erb` (delete), `app/javascript/controllers/list_controller.js` (delete), `spec/requests/events/rosters_spec.rb` (delete) and `spec/system/event_roster_edit_spec.rb` (delete) are deleted, and the comment in `app/javascript/controllers/type_to_confirm_controller.js` that cites the list controller stops naming it. `MOVED_ON` moves to `EventsController`.

## Seen red

Each example below is watched failing. Those that pass on the pre-fix code name the mutation that turns them red, in a throwaway edit that is never committed.

- Model: `#roster` orders by name whatever the case, a lowercase name between two capitalised ones. Red before the fix, where status leads.
- Model: `#roster(order: "status")` keeps today's grouping. Passes before the fix; dropping the status key turns it red.
- Request: the order controller sets the cookie and redirects back, signed in; signed out it redirects to sign-in; an unknown `order` leaves the cookie unset. Red before the fix, with no route.
- Request: a member of another group is refused by the order controller. Red before the fix; once it exists, removing its `authorize!` turns it red.
- Request: the event screen draws the list by status when the cookie says so, and by name otherwise, with `aria-sort` on the matching header. Red before the fix.
- Request: the edit form draws the list's fieldset for an administrator, with `+` on an off-list member and a trash on a listed one, and no "Fill the list". Red before the fix.
- Request: the manager's edit form draws the trash disabled with "only an administrator can remove". Red before the fix.
- Request: saving with an arrival and a removal reserves one place and destroys one registration. Red before the fix.
- Request: a manager posting a removal is refused and nothing is written. Red before the fix, where the param is ignored and the save succeeds.
- Request: an invalid event save with an arrival posted writes no registration. Passes before the fix, where nothing writes one; moving `update_roster` out of the transaction turns it red.
- Request: the new and duplicate forms still offer "Fill the list". Passes before the fix; drawing it only for a persisted record turns it red.
- System: in `spec/system/event_detail_spec.rb`, the Status header reorders the list and the order survives an answer pill press, axe-clean. Red before the fix.
- System: in `spec/system/event_form_spec.rb`, pressing `+` and the trash marks the rows, a second press unmarks, and Save lands both, axe-clean. Red before the fix.

## Steps

- Give `Event#roster` its name order and the `order:` argument
- Add the order controller, route, cookie helper and the `sort` legend meaning
- Draw the roster as a sortable table
- Move adding and removing into the event's edit form and its save, with "Fill the list" on new events only
- Remove Edit the list, its specs and its Stimulus controller
- Run the examples and mutations in "Seen red"

## Verification

- `bin/rspec spec/models/event_spec.rb spec/requests/events_spec.rb spec/requests/events/roster_orders_spec.rb` (new)
- Every example in "Seen red" was seen red, by the condition it names
- `bin/rspec spec/system/event_detail_spec.rb spec/system/event_form_spec.rb`
- `bin/rspec spec/styleguide`, which renders the roster and the edit form and which `bin/ci` does not run
- `bin/ci`

No gate here can tell whether a long list in the edit form reads well on a phone, or whether the struck-through and tinted marks are clear enough to trust before pressing Save.
