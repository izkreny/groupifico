> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Record the browser verification decision

Issue #186. Acceptance criteria live there.

## Why this issue exists at all

The decision was reached in the session that finished #186's description: one browser mechanism rather than two, Cuprite rather than Selenium, a system-spec suite that runs locally and never on a runner, and a small set of things that suite has to carry so an agent checking its own frontend work stops rewriting the same checks. None of that is visible in the result. A reader of #79's finished code sees `driven_by :cuprite` and cannot tell it was measured against the framework default, sees no `system-test` job in `.github/workflows/ci.yml` and cannot tell that is a choice rather than an omission, and sees a paint matcher without knowing which defect it exists for.

So this issue writes the record once and points the rest at it. That makes the trims part of the deliverable: `.agents/testing.md` stops deferring its system-spec conventions to a day that has now been decided, ADR 0001 stops describing a runner job that will not be built, and #79 stops carrying criteria the record contradicts.

## What the record is written from

- The two defects #172 shipped past its request specs, and the ~200-line Node harness attached to #186 that found both, which is the trigger.
- A survey of the reference codebases `CLAUDE.md` names, each read from source: what `rails new` generates, what the three Basecamp applications and hitobito drive their browser with, and the driver counts across the 196-app real-world corpus. The table is in #186's technical notes.
- The `gh-signoff` extension's README, read from the repository without installing the extension, for what a local signoff actually posts: a commit status whose context is `signoff` or `signoff/<name>`, never a name of the repository's choosing. That fact reshapes one paragraph of ADR 0001 and one criterion of #79, which is why it is read before the record is written rather than recalled.

## What ADR 0001 already says, and what changes

`docs/adr/2026-08-20_github-repository-conventions_0001.md` carries two paragraphs this record overturns. Its `-1` `app_id` paragraph calls local signoff "a preference to be tested rather than a settled rule"; this record settles it. Its "`system-test` was deleted, and it comes back as its own job" section describes a fifth runner job; this record says there is no runner job. Neither paragraph is deleted, since the history it records is true. Each gains one sentence pointing at 0005, the form 0003's `## Status` used for the Pundit reversal, so a reader of 0001 is sent to the current answer instead of finding two.

## Steps

- Write `docs/adr/2026-09-04_browser-verification_0005.md` in the `## Status`, `## Context`, `## Decision`, `## Consequences` shape of the four ADRs beside it, with the survey as the evidence for Cuprite, the harness as the evidence for the paint matcher and its control, and the signoff README as the evidence for the check's context
- Add one sentence to each of the two ADR 0001 paragraphs above, pointing at 0005
- Rewrite the system-spec bullet in `.agents/testing.md` so it points at the ADR instead of deferring its conventions to #79, leaving the Gemfile sentence alone until #79 changes the Gemfile
- Rewrite #79 against the record: title and criteria stop assuming a runner job, and gain Cuprite, `bin/ci` running the suite, the paint matcher with a control watched failing, the `signoff/<name>` check context, screenshots in `tmp/capybara`, and installing the extension as a named step for the owner; the reasoning is a citation of the ADR, not a copy
- Run the gates below

## Verification

- `bin/ci`, the repository's one local gate and a superset of its four CI jobs
- The `gh-solo` documentation check, for backticked paths that do not resolve and code fences that do not close
- `gh pr checks` green on `lint`, `scan_js`, `scan_ruby` and `test`

None of those gates can read. They prove the files parse, the paths resolve and nothing else in the repository broke; they say nothing about whether the argument holds, whether the survey numbers are quoted faithfully, or whether #79 now says what the record says. That judgement is the owner's, on the diff and on #79.

The #79 rewrite produces no diff, because an issue body is not a file. Its evidence is the issue itself, which is why #186's criterion for it is written against #79 rather than against this branch.

## Open questions

None. The decisions were made in the session that finished #186; what is left here is whether the record states them faithfully, which is a review comment rather than an open question.

## Settled

- **How many system specs, given that they never run on a runner?** Settled in the session after the review round: every view and every flow gets one, one spec file per view or flow, extended rather than rewritten when a later change touches the same view. Presence and absence of an element stay in the request specs; the browser suite asserts what a browser adds. The ADR's Cuprite argument was corrected to stop resting on a small suite.
- **Do ADR 0001's two `system-test` paragraphs keep their history with a pointer, or state the current answer?** Settled in the review threads: they are rewritten to the current answer, with the old expectation kept as one sentence of history each.
