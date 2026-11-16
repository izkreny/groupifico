> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: show the next rehearsal and gig on home (#459)

## Approach

`Group#featured_event` takes the category it answers for, `featured_event(:gig)` and `featured_event(:rehearsal)`, rather than gaining a sibling: two callers asking the same question of two categories is one method with an argument, and the name already says what it answers. Its running-before-upcoming ordering and the `confirmed` filter stay as they are, so the "Happening now" case needs no new branch, per N3. `GroupsHelper#featured_event_line` asks for `:gig`, per N2.

`GroupsController#show` assigns `@next_rehearsal` and `@next_gig`. `app/views/groups/show.html.erb` draws its first-run state when the group has no events at all (`@group.events.none?`), per AC5, and otherwise a grid of two slots, rehearsal first: each slot renders `events/_next_up` for its event or a `card card-sm` carrying "No rehearsal coming up" or "No gig coming up". The grid is one column on a phone and `md:grid-cols-2` from the `md` breakpoint up. The single "See all events" link under the pair stays, and it is the link to the group's events that AC4 asks for, so the empty slot carries none of its own.

**Side by side was measured before planning.** The shell's column is `max-w-[40rem]` with `px-4`, so two columns with a `gap-4` leave each card 296px. The unchanged hero rendered at a 296px column, as an owner with Duplicate and Edit, once with the answer pills and once with Request responses, overflowed nothing: only the counts row wrapped to a second line.

**Nearly every home example plants an `other` event today**, the factory's default category, including `confirmed_event_spanning` in `spec/requests/groups_spec.rb`, the `#featured_event` model examples and `spec/helpers/groups_helper_spec.rb`. Once `other` leaves the hero those examples lose their card. A spec-only commit gives them a category first, green on unchanged production code, so the behaviour change never shares a commit with that churn. The factory gains a `:gig` trait beside its `:rehearsal`.

## Steps

- ::S1:: Add a `:gig` trait to `spec/factories/events.rb`, and give every event a home-card, `#featured_event` or `#featured_event_line` example relies on a category through the `:rehearsal` or `:gig` trait, in `spec/requests/groups_spec.rb`, `spec/models/group_spec.rb`, `spec/helpers/groups_helper_spec.rb` and any system spec under `spec/system/` that draws the home's card. Production code unchanged
- ::S2:: `Group#featured_event(category)` in `app/models/group.rb` and its comment; `featured_event_line` in `app/helpers/groups_helper.rb` asks for `:gig`; `GroupsController#show` assigns `@next_rehearsal` and `@next_gig`; `app/views/groups/show.html.erb` draws the two-slot grid and its first-run state for a group with no events. Specs: in `spec/models/group_spec.rb` the existing examples pass a category, plus an earlier rehearsal and an `other` event losing to a gig (AC1, AC2), an earlier gig and an `other` event losing to a rehearsal (AC7), and a running rehearsal (AC8); in `spec/helpers/groups_helper_spec.rb` an earlier rehearsal that the gig line ignores (AC6); in `spec/requests/groups_spec.rb` both cards with a gig after a rehearsal (AC1, AC7), an `other` event's name absent with both cards drawn (AC2), a running gig's kicker (AC3) and a running rehearsal's (AC8), "No gig coming up" with only a rehearsal ahead and with only an `other` event ahead (AC4), "No rehearsal coming up" with only a gig ahead (AC9), "Nothing in the diary" for a group with no events (AC5) and the two empty lines rather than it for a group whose only event is past, and the rehearsal card's markup before the gig card's (AC10); in `spec/system/group_home_spec.rb` both cards painting with no accessibility violations, the rehearsal card above the gig card at `ViewportHelper::MOBILE` and to its left at `ViewportHelper::DESKTOP` with nothing overflowing (AC10), and an empty slot painting. Every comment the change makes false is rewritten, in `spec/` and `app/`

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-15_GHI-459_next-rehearsal-and-gig.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-15_GHI-459_next-rehearsal-and-gig.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/group_spec.rb spec/helpers/groups_helper_spec.rb spec/requests/groups_spec.rb` passes after S1 on unchanged production code, and after S2; each new example of S2 is seen failing against `app/models/group.rb`, `app/helpers/groups_helper.rb`, `app/controllers/groups_controller.rb` and `app/views/groups/show.html.erb` as they are on `main`, except the AC3 example and the AC5 example, which pass there and are seen failing instead against the S2 code with `.where(category:)` dropped from `Group#featured_event` (AC3, with an earlier rehearsal planted beside the running gig) and with the first-run branch's `@group.events.none?` replaced by `@next_rehearsal.nil? && @next_gig.nil?` (the AC5 boundary example)
- ::V4:: `mise exec -- bin/rspec spec/system/group_home_spec.rb` passes; the AC10 placement example is seen failing against the S2 view with the gig slot written before the rehearsal slot, and against it with `md:grid-cols-2` removed
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments app/views/groups/show.html.erb` exit 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The specs prove which event each card draws, which empty line stands in for it, and where the two sit; whether the pair reads well side by side on a desktop and stacked on a phone is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

None yet.
