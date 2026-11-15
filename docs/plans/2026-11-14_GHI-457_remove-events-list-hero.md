> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: remove the hero from the events list (#457)

## Approach

`app/views/events/index.html.erb` stops rendering `events/_next_up` and draws every event in `@events` as a row, and its empty sentence stands whenever `@events` is empty; `EventsController#index` drops `@featured_event` and its comment, per N1. The partial stays, since the group home renders it, per N2.

**The card's own coverage moves to the group home rather than leaving with the list.** Most of what proves `events/_next_up` (its Duplicate and Edit, the roster link, the pills, the counts, Request responses, its spacing, paint and fit) is asserted only through the events list today, and `spec/requests/groups_spec.rb` and `spec/system/group_home_spec.rb` cover nothing of it beyond the kicker, the running event, the question and the card painting. Deleting those examples with the list's hero would leave a partial that still ships unprotected, so they are relocated to the screen that still draws it, deduplicated against what the group home already asserts. Every card example in `spec/requests/events_spec.rb` was run against `group_path` before this plan was written, and every card assertion passed there; only the row halves failed, and they stay with the list.

The relocation is a spec-only commit, green on unchanged production code, ahead of the behaviour change, so the two never share a commit. What remains on the list loses its hero halves: the examples that drew a hero above a row keep the row, the past and canceled examples lose their "no hero card" assertion, and the examples that existed only to prove which event the list's hero took go, per the owner's rule that a removed element loses its specs rather than gaining an absence assertion. AC1 is that absence, so it is proven by the AC2 example: the event `Group#featured_event` answers is drawn as an ordinary row, in date order, which no list carrying the hero could render.

Comments that describe the list's hero become false and are rewritten, in specs and in `app/`: `GroupsController#show`'s, the `_next_up` header, `Events::ResponseRequestsController`'s and its spec's, the styleguide's confirmed-status description, and the group home spec's pointers at the list spec.

## Steps

- ::S1:: Move the card's own examples from `spec/requests/events_spec.rb` into `spec/requests/groups_spec.rb`'s `GET /groups/:id`, retargeted at `group_path`: Duplicate before Edit, Edit alone for a manager, the roster link, the answer and counts for a member who has answered, the pills, no pills for a paused member, the no-response-requested sentence, and every Request responses case, plus the card halves of the Edit example and the hero-and-row example, each deduplicated against the group home's existing kicker, running-event and question examples. Move the card's browser examples from `spec/system/events_list_spec.rb` into `spec/system/group_home_spec.rb`: the lit pill's paint folded into the home's two paint examples, the roster landing, the spacing and kicker examples, the lit pill's contrast in both themes, the fit at both widths with `overflowing?`, the answer written in place, Request responses in both themes, and the Duplicate and Edit sizes. Rewrite the home spec's comments that point at the list spec. Production code unchanged
- ::S2:: Remove the hero from the events list per N1 in `app/views/events/index.html.erb` and `app/controllers/events_controller.rb`. In `spec/requests/events_spec.rb`, add the example that draws the featured event as a row between an earlier and a later one, named for AC1 and AC2, name the empty upcoming list's example for AC3, delete the running-event hero example and the unconfirmed-only "draws no hero card" example, keep only the row halves of the Edit, hero-and-row and question-order examples, and drop the "no hero card" assertion and wording from the past and canceled examples. Rename `spec/requests/addresses_spec.rb`'s map link example for rows alone, fix any list example that breaks because its planted hero event is now a row, and rewrite every comment the change makes false, in `spec/` and `app/` (AC1, AC2, AC3)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-14_GHI-457_remove-events-list-hero.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-14_GHI-457_remove-events-list-hero.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/groups_spec.rb` passes; every relocated card example is seen failing against `app/views/groups/show.html.erb` with its `render "events/next_up"` line deleted
- ::V4:: `mise exec -- bin/rspec spec/system/group_home_spec.rb` passes; every relocated card example is seen failing against the same deletion
- ::V5:: `mise exec -- bin/rspec spec/requests/events_spec.rb spec/requests/addresses_spec.rb spec/requests/events/response_requests_spec.rb` passes; the AC1 and AC2 example is seen failing against `app/views/events/index.html.erb` and `EventsController#index` as they are on `main`, and the AC3 example against the index with its empty sentence's branch deleted
- ::V6:: `mise exec -- bin/rspec spec/system/events_list_spec.rb` passes
- ::V7:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments app/views/events/index.html.erb` exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The specs prove that the featured event is a row and the card still works where it remains, not that the list reads well without it: that is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

None yet.
