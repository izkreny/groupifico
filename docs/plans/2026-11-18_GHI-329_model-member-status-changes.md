> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Model member status changes

Issue #329, a spike. Its deliverable is an ADR recording the decision, with the issues that hang off it updated to match.

## What the record is written from

A grilling session with the owner settled the design question by question, and four research passes informed it, each reading source rather than recalling it:

- the 37signals applications and edge Rails, for the house style and what the framework ships
- the `steveclarke_real-world-rails` corpus, for how production applications change state with and without a state-machine gem, and how they keep dated histories
- Hitobito, the association-management application closest to this domain
- the `state_machines` family's repositories, and a run of `state_machines-activerecord` 0.304.0 against this app's enum shape

## Steps

- ::S1:: Write `docs/adr/2026-11-18_member-status-changes_0008.md` (new) in the shape of the ADRs beside it, with status Proposed, because the choice between plain Rails and the `state_machines` gem waits on questions put to that gem's maintainers
- ::S2:: Bring the tracker in line with it: #126 finished as the core and blocked by #329, #92 closed into it, #322, #330, #448 and #115 rewritten, #477 to #482 opened, and #143 and #353 annotated
- ::S3:: Run the gates below

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-18_GHI-329_model-member-status-changes.md`
- ::V2:: The `gh-solo` documentation check over the plan and the ADR, for backticked paths that do not resolve and code fences that do not close
- ::V3:: `bin/ci`, the repository's one local gate
- ::V4:: `gh pr checks` green on `lint`, `scan_js`, `scan_ruby` and `test`

None of these gates can read. They say nothing about whether the ADR states the decisions faithfully, or whether the issue bodies match it, which is the owner's judgement on the diff and on the issues. S2 produces no diff, because an issue body is not a file.

## Open questions

None. The design questions were settled in the grilling session. The one choice left open, plain Rails or `state_machines`, is the ADR's to record as open rather than this branch's to settle, which is why the pull request refers to #329 rather than closing it.

## Settled

None yet.
