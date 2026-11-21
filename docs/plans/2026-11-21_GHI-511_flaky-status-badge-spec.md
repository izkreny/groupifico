> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fix the flaky status-badge spec on the event form (#511)

## Approach

The example builds each listed member with the `:member` factory, so their full names come from Faker and are interpolated into an XPath string literal; a name with an apostrophe ends that literal early. Following the sibling `detailed_event` helper in `spec/requests/events_spec.rb` (N1), the three listed members get users built with `:with_full_profile` and literal first and last names, one per status, so nothing Faker draws reaches the XPath. The assertion and the view stay untouched, which keeps the example's teeth (AC2).

A `# WHY: #511 AC1` comment above the example states why the names are literals, matching the `# WHY: #460 AC1` comments elsewhere in the file.

## Steps

- ::S1:: Prepare the worktree's test database and reproduce the failure on the unchanged example with `--seed 12177` (N2)
- ::S2:: Give the three listed members literal names via `create(:user, :with_full_profile, first_name:, last_name:)` and add the `WHY` comment, in one `test` commit
- ::S3:: Watch the example fail with the badge `<span>` deleted from `app/views/events/_list_name.html.erb`, then restore the view

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-511_flaky-status-badge-spec.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-511_flaky-status-badge-spec.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/events_spec.rb --seed 12177` exits 0; seen to exit 1 on the unchanged example (AC1)
- ::V4:: `mise exec -- bin/rspec spec/requests/events_spec.rb -e 'badges a member on the list who is not active'` exits 0; seen to exit 1 with the badge `<span>` deleted from `app/views/events/_list_name.html.erb` (AC2)
- ::V5:: `mise exec -- bin/ci` passes, browser suite included

No gate proves the example passes for every possible Faker draw; it stops reading Faker names at all, which V3's fixed seed only samples.

## Open questions

None.

## Settled

- ::Q1:: Does this branch also fix the same flake elsewhere, the `press` helper in `spec/system/event_form_spec.rb` quoting Faker names in a CSS selector? Yes, inside this pull request: the owner decided so in the session on 2026-11-21.
