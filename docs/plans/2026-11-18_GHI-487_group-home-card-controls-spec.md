> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fix the group home card controls spec (#487)

## Approach

The example "lands on Duplicate's form and on Edit's from the card's controls" in `spec/system/group_home_spec.rb` reads `page.current_path` straight after each `click_link`, and `current_path` returns at once rather than waiting, so both reads race Turbo's navigation (N1). Per N2, each read becomes `expect(page).to have_current_path(...)` right after its click, which Capybara retries until the landing happens or the wait runs out, the way the rest of the suite asserts a landing. The example keeps its one setup and its two presses; only the assertions move, and the app code does not change. Its `WHY:` comment gains `#487 AC1 and AC2` beside `#473 AC3`, since the example now carries both issues' claims.

## Steps

- ::S1:: In `spec/system/group_home_spec.rb`, replace the stored `duplicated = page.current_path` and the closing pair comparison with `expect(page).to have_current_path duplicate_group_event_path(member.group, event)` after the Duplicate click and `expect(page).to have_current_path edit_group_event_path(member.group, event)` after the Edit click, and name `#487 AC1 and AC2` in the example's `WHY:` comment (AC1, AC2)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-18_GHI-487_group-home-card-controls-spec.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-18_GHI-487_group-home-card-controls-spec.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/system/group_home_spec.rb` passes; the rewritten example passes on the app as it is on `main`, so it is seen failing instead against two mutations of `app/views/events/_next_up.html.erb`, each reverted after: the Duplicate link pointed at `edit_group_event_path`, then the Edit link pointed at `duplicate_group_event_path` (AC2)
- ::V4:: `mise exec -- bin/rubocop spec/system/group_home_spec.rb` exits 0
- ::V5:: `mise exec -- bin/ci` passes, browser suite included (AC1)

The race is timing-dependent, so one green `bin/ci` shows the example no longer fails where it failed on every run before, not that no machine could ever outrun Capybara's default wait.

## Open questions

None.

## Settled

None yet.
