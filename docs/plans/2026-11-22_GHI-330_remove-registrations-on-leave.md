> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: remove registrations when a member leaves (#330)

## Approach

ADR 0008 (`docs/adr/2026-11-18_member-status-changes_0008.md`) decides what leaving `active` removes, and #126 left the place for it: `Member::Statuses` gains one `before_transition from: :active, to: %i[ paused inactive ]` beside the day's-change callbacks, which removes the member's registrations inside the transition's own transaction (N1). `pending` never reaches it, and `activate` has no callback, so returning to `active` creates nothing (AC5, N3).

### Which registrations go

The callback reads the member's registrations once, with their events preloaded, narrowed in SQL to events ending on or after the start of `status_starts_on` in the app's zone, so a backdated change reaches the events since its start date and none before it (N2). Of those, each event's own predicates decide, read in Ruby so "open to answers" keeps its one spelling in `Event#open_to_answers?`:

| Event | Registrations removed |
| --- | --- |
| Open to answers, not ended | every one, answered or not (AC1, AC2) |
| Open to answers, ended on or after the start date | `reserved` and `response_requested`, so `yes`, `maybe` and `no` stay (AC9) |
| `concluded` or `canceled`, whatever its dates | none (AC10, Q1) |
| Ended before the start date | none (AC10) |

"Ended" is `Event#ended?`, read inside the save, so it compares `ends_at` with the moment of the change (N1). Each registration goes through `destroy!`, as `Event#update_roster` destroys a roster's leavers, so a callback `Registration` gains later still runs.

### A refused change deletes nothing

A `before_transition` runs before the save validates, so the removal has already happened when a validation refuses the change, as for the group's last active owner (AC6) or a start date after today. The machine's own transaction rolls it back. Inside `MembersController#update_with_status` the machine's transaction joins the controller's and its rollback is swallowed there, so the controller's own `raise ActiveRecord::Rollback` is what undoes it, and AC6 is proven on both paths. A blank start date reaches the callback as `nil`, so the callback removes nothing for it and leaves the refusal to the start date validation, rather than raising before the form can show the field's error. The callback never returns `false`, which the machine reads as a halt.

## Steps

- ::S1:: In `app/models/member/statuses.rb`, add the `before_transition from: :active, to: %i[ paused inactive ]` and the private method it calls, reading the registrations as *Which registrations go* says. In `spec/models/member_spec.rb`, add "#330 AC1", "#330 AC2", "#330 AC5", "#330 AC6" (the last active owner, a start date after today and a blank one), "#330 AC9" and "#330 AC10" examples under `travel_to`, with literal `starts_at`, `ends_at` and `status` on every event and each answer written while its event still takes it, plus a boundary pair for a backdated change: an event ending at 00:30 on the start date, which loses its unanswered registration, and one ending at 23:30 the day before, which keeps it
- ::S2:: In `spec/requests/members_spec.rb`, beside the #126 examples under `PATCH /groups/:group_id/members/:id`, add "#330 AC7" for the form's pause removing a registration on an event that has not ended, the one example where the member is strict-loaded, and "#330 AC6" for a start date after today answering the field's error with the registration still there

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-22_GHI-330_remove-registrations-on-leave.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-22_GHI-330_remove-registrations-on-leave.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/member_spec.rb` passes. AC1's, AC2's and AC9's removals are seen failing on the pre-fix code, AC9's kept answers on the `answered?` check removed, AC10 on the `open_to_answers?` check removed and again on the date narrowing removed, the boundary pair on the narrowing taken from the date in UTC, AC6's last-owner and future-date examples on the removal moved out of the callback into `change_status` ahead of the event, its blank-date example on the `nil` guard removed, and AC5 on a throwaway `after_transition to: :active` that reserves the member on every upcoming event
- ::V4:: `mise exec -- bin/rspec spec/requests/members_spec.rb` passes, AC7's example seen failing on the pre-fix code and AC6's on the controller's `raise ActiveRecord::Rollback` removed
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see a real group's rosters after a member leaves, since nothing on screen changes beyond a row that is gone.

## Open questions

- ::Q1:: When a member leaves `active`, does an upcoming event that is already `canceled` or `concluded` lose their registrations? 1. Yes, as AC1's "every event that has not ended" reads. 2. No, as AC10's "whatever their status" and ADR 0008's "never touched" read. Built as 2 and pinned by a "#330 AC10" example, so 1 is a one-line change to the filter.

## Settled

None yet.
