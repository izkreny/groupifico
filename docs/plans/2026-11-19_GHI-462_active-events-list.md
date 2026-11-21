> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add an active events list for admins (#462)

## Approach

`Event::Filter` keeps the convention `Member::Filter` and `ListFilter` share, where the `nil` tab is the screen's own URL, but `nil` stops meaning Upcoming and starts meaning the reader's default list: Active for a member who oversees the group's events, Upcoming for everyone else. Each list gets a named value, `active`, `upcoming`, `past` and `canceled`. The filter resolves `scope` against the lists it offers this reader, falls back to the default for anything it does not offer, and writes the default back as `nil`. So a non-manager's URLs are exactly what they are today, a manager's bare URL opens Active, and `scope=upcoming` names Upcoming for every member (AC3, AC4, AC5, AC9).

Whether the reader oversees is the policy's answer, handed in by the controller as `oversees:`, the way `MembersController` hands `MemberPolicy#oversee?` to `Member::Filter`. `EventPolicy#oversee?` is `membership.can_manage?(:events)` (N1). It stays outside `ApplicationPolicy::WRITE_RULES`, so a paused events manager keeps the tab as a paused members overseer keeps Pending and Inactive.

Active is a new `Event.active` scope, statuses `unconfirmed` and `confirmed` whatever the dates, ordered by start. It is offered first, so the tabs read Active, Upcoming, Past, Canceled (AC1, AC2). The filters narrow it like any list, and its count comes from the same `counts` over the offered tabs (AC6, AC8). The comments claiming the three lists partition the group's events, in `app/models/event.rb` and `app/controllers/events_controller.rb`, say that Active is a view across Upcoming and Past (N2).

The hero's "All upcoming gigs" link carries `scope=upcoming`, and its count in `GroupsController#show` names the same list, so the link and its count cannot disagree whoever reads them (AC9).

## Steps

- ::S1:: Refactor, behaviour unchanged: `Event::Filter` resolves a named list behind its `nil` tab, `on_tab` and `counts` read the offered tabs rather than `TABS` and an `else` branch, and the index's empty sentence reads the resolved list, all guarded by the existing `spec/models/event/filter_spec.rb` and `spec/requests/events_spec.rb`
- ::S2:: Add `Event.active` with its examples in `spec/models/event_spec.rb`, and update the partition comments in `app/models/event.rb` and `app/controllers/events_controller.rb` (AC1, N2)
- ::S3:: Add `EventPolicy#oversee?` with per-column examples in `spec/policies/event_policy_spec.rb`, and the "See the Active list" row in `docs/AUTHORIZATION.md`'s events table with the note that it is a read (AC7)
- ::S4:: Offer Active through `oversees:`: `Event::Filter` takes it, puts Active first and makes it the overseer's default, `scope=upcoming` resolves for every reader, and `EventsController#index` passes `allowed_to?(:oversee?, …)`; examples in `spec/models/event/filter_spec.rb` for the offered tabs, the defaults, the dropped `active`, the filters on Active and its count, and in `spec/requests/events_spec.rb` for the tabs each column sees and lands on (AC1 to AC6, AC8)
- ::S5:: Point the hero link at `scope=upcoming` and name the list in `GroupsController#show`'s count, rewriting the hrefs `spec/requests/groups_spec.rb` asserts and adding a manager example with a past unconcluded gig (AC9)
- ::S6:: Bring the comments that say a bare or unknown events URL means Upcoming in line, in `app/models/event/filter.rb`, `app/controllers/events_controller.rb`, `app/controllers/members_controller.rb` and `docs/AUTHORIZATION.md`, and the styleguide's `Event::Filter` sample if it needs `oversees:`
- ::S7:: Extend `spec/system/events_list_spec.rb` with axe on a manager's list showing four tabs, in organic and organic-dark (AC2)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-19_GHI-462_active-events-list.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-19_GHI-462_active-events-list.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/event_spec.rb spec/models/event/filter_spec.rb spec/policies/event_policy_spec.rb` passes; the `Event.active` examples are seen red against a scope reading `current_and_upcoming`, the overseer examples against `main`'s filter, the non-overseer default and dropped-`active` examples against a filter that offers Active to everyone, and the `oversee?` examples against a rule answering `true`
- ::V4:: `mise exec -- bin/rspec spec/requests/events_spec.rb spec/requests/groups_spec.rb spec/requests/styleguides_spec.rb` passes; the manager tab and landing examples are seen red on `main`'s controller, the non-manager examples against a controller passing `oversees: true`, and the hero examples against the link and count without `scope`
- ::V5:: `mise exec -- bin/rspec spec/system/events_list_spec.rb` passes, the axe examples seen red with the Active tab's label in a colour axe fails
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove which tabs each member is offered and where each URL lands, not that four tabs read well in the row at phone width; that is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

- ::Q1:: Active and Upcoming would mostly list the same events, so is a second everything-still-open tab the right shape? No: settled by the owner in the terminal on 2026-11-21, the tab becomes To do, third after Past, where Pending sits on the members list, and shown only to the `EventPolicy#oversee?` columns, listing the events waiting on them, today those that ended still unconfirmed or confirmed. Upcoming stays every member's default, so the home hero's gigs link needs no `scope` and AC9 is removed from #462.
- ::Q2:: Should To do also hold the unconfirmed events still ahead? Yes: settled by the owner in a thread on #497 on 2026-11-21, To do lists every unconfirmed event, whatever its dates, and every past event still confirmed, oldest first so the longest waiting leads, and it overlaps Upcoming as well as Past.
