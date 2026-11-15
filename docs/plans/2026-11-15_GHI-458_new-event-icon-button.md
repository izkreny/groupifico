> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: shrink the new event button to an icon (#458)

## Approach

`app/views/events/index.html.erb` keeps its `allowed_to?(:create?, @group.events.new)` guard and swaps the labelled `btn btn-primary btn-sm` link for the hero card's icon button per N1: `btn btn-ghost btn-circle btn-sm text-primary` around the `:new` icon at `size-icon-control`, with `aria-label` "New event". The app stylesheet already sizes every `btn-sm` circle to `--spacing-control`, so the + takes the hero's 32px box around a 20px glyph with no new class. The group home's empty-state button stays labelled, per N2.

The styleguide follows the app: `app/views/styleguides/components/_labelled_buttons.html.erb` lists every labelled button in the classes its screen gives it, so its small "New event" goes, since no screen draws one any more, and the `new:` entry of `StyleguidesHelper::ICON_USES` names the + on the events list.

## Steps

- ::S1:: Replace the events list's labelled New event link with the icon-only + per N1 in `app/views/events/index.html.erb`. In `spec/requests/events_spec.rb`, rewrite the owner's New event example to assert a link to the new event form whose accessible name is "New event" and whose only content is the icon, named for AC1 and AC2, and name the plain member's no-button example for AC3. In `spec/system/events_list_spec.rb`, add an example that presses the + by its accessible name and lands on the new event form, named for AC2, and one that measures the + as a 32px circle around a 20px glyph, the box and glyph of the hero's Duplicate and Edit, in support of AC4 (AC1, AC2, AC3)
- ::S2:: Drop the small "New event" from `app/views/styleguides/components/_labelled_buttons.html.erb`, and say "the + on the events list" in the `new:` entry of `StyleguidesHelper::ICON_USES`

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-15_GHI-458_new-event-icon-button.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-15_GHI-458_new-event-icon-button.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/events_spec.rb` passes; the AC1 and AC2 example is seen failing against `app/views/events/index.html.erb` as it is on `main`, and the AC3 example, which passes there, against the index with its `allowed_to?` guard removed
- ::V4:: `mise exec -- bin/rspec spec/system/events_list_spec.rb` passes; the measuring example is seen failing against the index as it is on `main`, and the AC2 example, which passes there by the link's text, against the + with its `aria-label` removed
- ::V5:: `mise exec -- bin/rspec spec/styleguide` passes
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove the + is there for the right members, named, sized and landing on the form, not that it reads as the hero's sibling or that the header balances with it at the right edge: AC4 is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

None yet.
