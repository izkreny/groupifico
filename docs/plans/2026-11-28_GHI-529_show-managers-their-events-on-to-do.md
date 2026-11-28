> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: show managers their events on to do (#529)

## Approach

`Event::Filter` gains a third policy answer, `may_edit_managed`, beside `may_edit` and `may_answer`, and `#waiting_on_member` adds `events.to_do.where(manager: member)` for it (N1). `#counts` reaches To do through `#on_tab` like `#apply` does, so the tab's count takes the new reason with no change of its own (N3), and only gets an example.

`EventsController#index` asks `EventPolicy#update?` of `Event.new(group: @group, manager: Current.member)`, an event with nothing on it but the group and the reader as its manager (N2). `manages?` admits every active member to it, and `ApplicationPolicy`'s status pre-check refuses a paused one, since `update?` is in `WRITE_RULES`, so AC4 is the policy's answer rather than a status read in the filter. The existing `may_edit` question stays as it is. With `has_many_inversing` on, building that event puts it in `Current.member.managed_events`'s in-memory target, and the one reader of that association in the request is `Event::Filter#managed_offered?`, which asks `exists?` of the database, so it does not see the unsaved event.

### Only for a member who may not edit the group's events

The managed reason is added only when `may_edit` is false, as N1 words it. Every event it finds is already in `events.to_do`, so for a member holding an events role it would only lengthen the query, and AC5 is the existing reason left alone.

### Prose that states the old rule

`docs/AUTHORIZATION.md` marks `manager` on the *See on To do the events waiting on whoever runs them* row, and the To do paragraph loses its last two sentences, which explain why the column is unmarked, for one saying the manager's To do adds the waiting events they manage (AC6). The paragraph that opens "Some rows above have no rule of their own" goes false too, though AC6 does not name it: it says the controller asks of an event with no manager, and that the row keeps its own line because its `manager` cell differs from the edit row's, which after this change it does not. It is corrected to say the controller asks twice, the second time of an event the reader manages, and the sentence about the differing cell goes. The WHY on `#waiting_on_member`, the WHY in `EventsController#index` and the WHY on `Event::Filter.from` name two policy answers and flip with the code.

## Steps

- ::S1:: In `app/models/event/filter.rb`, add `may_edit_managed:` to `.from` and `#initialize`, store it beside the other two with a `may_edit_managed?` reader, and in `#waiting_on_member` add `events.to_do.where(manager: member)` when `may_edit_managed?` holds and `may_edit?` does not. Rewrite the WHY on `.from` and on `#waiting_on_member`
- ::S2:: In `spec/models/event/filter_spec.rb`, pass `may_edit_managed: false` to the `.from` calls, and add under `#apply` a member with `may_edit_managed: true` seeing their unconfirmed event and their past one still confirmed on To do, oldest first (AC1), not seeing a waiting event somebody else manages or one with no manager (AC2), and a member with `may_edit: true` and `may_edit_managed: true` seeing a waiting event somebody else manages beside their own (AC5). Add under `#counts` the managed member's To do count matching the events `#apply` lists (AC3). Each is headed `# WHY: GHI-529 ACn.`
- ::S3:: In `app/controllers/events_controller.rb`, hand `may_edit_managed: allowed_to?(:update?, Event.new(group: @group, manager: Current.member))` to `Event::Filter.from` and rewrite the WHY above it
- ::S4:: In `spec/requests/events_spec.rb`, rewrite "offers To do with none of the events waiting on whoever runs the group's events" under the manager context into the manager opening To do and finding their unconfirmed event and their past one still confirmed, the tab reading the count of those rows, and neither another manager's waiting event nor one with no manager (AC1, AC2, AC3). Add a paused manager whose To do says "Nothing to do." with the tab at `To do (0)` (AC4), and under the events administrator context one who manages a waiting event and finds another manager's waiting event on To do beside it (AC5)
- ::S5:: In `docs/AUTHORIZATION.md`, mark `manager` on the To do row, replace the To do paragraph's last two sentences, and correct the "Some rows above have no rule of their own" paragraph, each as *Prose that states the old rule* says

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-28_GHI-529_show-managers-their-events-on-to-do.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-28_GHI-529_show-managers-their-events-on-to-do.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/event/filter_spec.rb` passes. AC1's and AC3's examples are seen failing on the pre-fix `#waiting_on_member`, AC2's on `#waiting_on_member` adding `events.to_do` rather than `events.to_do.where(manager: member)` for `may_edit_managed?`, and AC5's on `#waiting_on_member` checking `may_edit_managed?` before `may_edit?`, so a member holding both gets only the events they manage
- ::V4:: `mise exec -- bin/rspec spec/requests/events_spec.rb` passes. The rewritten AC1, AC2 and AC3 example is seen failing on the pre-fix filter and controller, and on the widening V3 names for AC2, AC4's on the controller handing in `may_edit_managed: true` rather than asking the policy, and AC5's on the same `#waiting_on_member` reordering V3 names
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether a manager's To do listing the events they run reads as intended on a real group, which is the owner's to judge on screen.

## Open questions

None.

## Settled

None yet.
