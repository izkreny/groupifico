> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: show members their own to do (#502)

## Approach

A new `Event.awaiting_answer_from(member)` scope states the member's reason once, in SQL: an event still `unconfirmed` or `confirmed` whose registration for that member is `response_requested`, or, once the event has ended, `reserved`, `response_requested` or `maybe`. That is `Registration#response_due? && Event#open_to_answers?` read across a list rather than a row, so the tab holds exactly the rows that ask the member "Are you coming?" or "Did you go?". Both halves are `where(id: subquery)` off one base relation, and the ended half keeps the open-status condition, since `Event.past` holds concluded events too.

`Event::Filter` drops `OVERSEER_TABS`, so every member is offered To do. Its list is the member's own reason, plus `Event.to_do` when `oversees:` is true, joined with `or` so each event appears once, ordered by `starts_at` as today. `EventPolicy#oversee?` therefore stops deciding who sees the tab and starts deciding what the list adds, and every comment and spec description that says otherwise changes with it.

A paused member answers nothing, because `RegistrationPolicy#update?` is a write rule, so their rows ask nothing and their own reason stays off their To do (Q1). The controller asks the policy whether the member may answer their own registration and hands that in, as it already hands in `oversees:`. A paused events administrator keeps the half `oversee?` adds, which is a read.

## Steps

- ::S1:: Add `Event.awaiting_answer_from(member)` with examples in `spec/models/event_spec.rb` built from a hand-written table of every registration status on an upcoming and an ended event, plus a concluded and a canceled one, under `freeze_time` (AC2, AC3, AC4)
- ::S2:: Offer To do to every member: `Event::Filter` drops `OVERSEER_TABS` and lists the member's own reason, when they may answer, joined with `Event.to_do` when they oversee the events; `EventsController#index` hands in whether the member may answer, from `RegistrationPolicy#update?`; the comments in `app/models/event/filter.rb`, `app/controllers/events_controller.rb` and `app/policies/event_policy.rb` say what `oversee?` now adds; the styleguide's sample in `app/views/styleguides/show.html.erb` counts To do (AC1, AC5, AC6)
- ::S3:: Rewrite the examples #462 wrote for a member offered no To do tab, in `spec/models/event/filter_spec.rb` and `spec/requests/events_spec.rb`, as examples of the tab every column now gets, and add the member's list, the overseer's single list, the order and the paused member; reword the descriptions in `spec/policies/event_policy_spec.rb` that call `oversee?` seeing the To do list
- ::S4:: Mark every column of "See the To do list" in `docs/AUTHORIZATION.md` and rewrite the note under the events table to say what each member's list holds and what `oversee?` adds (AC7, N2)
- ::S5:: Extend `spec/system/events_list_spec.rb` with a member holding no role whose tab row carries To do with its count, passing axe in organic and organic-dark

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-23_GHI-502_show-members-their-own-to-do.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-23_GHI-502_show-members-their-own-to-do.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/event_spec.rb` passes; the `awaiting_answer_from` examples are seen red against a scope reading `response_requested` alone (the ended `reserved` and `maybe` rows), against one without the status condition (concluded and canceled), and against one reading every unanswered status whatever the dates (the upcoming `reserved` and `maybe` rows)
- ::V4:: `mise exec -- bin/rspec spec/models/event/filter_spec.rb spec/policies/event_policy_spec.rb` passes; the member's tab and list examples are seen red on `main`'s filter, the overseer's single list against a filter listing the member's own reason alone, the order against `starts_at: :desc`, and the paused example against a filter ignoring whether the member may answer
- ::V5:: `mise exec -- bin/rspec spec/requests/events_spec.rb spec/requests/styleguides_spec.rb` passes; the per-column tab examples are seen red on `main`'s controller, and the paused member's against a controller handing in `true` for whether they may answer
- ::V6:: `mise exec -- bin/rspec spec/system/events_list_spec.rb spec/styleguide` passes, the styleguide's included because `bin/ci` never runs it; the member's To do example is seen red on `main`'s filter, which offers them no To do tab
- ::V7:: `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views and `mise exec -- bin/rubocop` over the changed Ruby files exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The specs prove which events each member's To do holds and that every column is offered it; they cannot see whether a To do tab on every member's screen reads as their own inbox rather than as a list about the group's events.

## Open questions

None.

## Settled

- ::Q1:: A paused member cannot answer, so their rows ask nothing: does their To do leave out their own reason? Yes: settled by the owner in the terminal on 2026-11-23.
- ::Q2:: Does a paused events administrator keep the events waiting on whoever runs them, as #462 gave them? No: settled by the owner in the terminal on 2026-11-23, since confirming or concluding an event is an edit a paused member is refused, so a paused member's To do is empty. The controller asks `EventPolicy#update?` of an event with nothing on it but the group in place of `EventPolicy#oversee?`, which goes with its examples.
