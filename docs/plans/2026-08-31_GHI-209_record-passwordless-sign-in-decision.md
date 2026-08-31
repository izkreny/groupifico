> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Record the passwordless sign-in decision

Issue #209. Acceptance criteria live there.

## Why this issue exists at all

The reasoning behind passwordless sign-in was reached across #139, #207 and #208, and none of the three explains itself. Each was carrying its own copy of the same research, which is two ways of being wrong at once: a reader of any one of them cannot see the argument, and three copies of one fact drift the moment any of them is edited.

So this issue writes the record once and points the three at it. That makes the trim part of the deliverable rather than tidying afterwards: an ADR that leaves the duplicates in place has not removed anything.

## What the record is written from

Four passes, each reading source rather than recalling it, per the standing rule in `CLAUDE.md` that `rails_rails` outranks everything on framework capability and `basecamp_*` gets preference on application patterns:

- the framework itself, for what Rails ships and what it does not
- the `steveclarke_real-world-rails` corpus, for what production applications actually do
- the Ruby Toolbox `rails_authentication` category, for what a gem would buy
- the source, tests and changelogs of `passwordless`, `devise-passwordless`, `nopassword` and `rodauth`, for what each learned the hard way

The fourth pass is the one that changed the design rather than confirming it, and the ADR carries its findings as decisions rather than as trivia.

## Steps

- Write `docs/adr/2026-08-31_passwordless-email-sign-in_0004.md`, following the `## Status`, `## Context`, `## Decision`, `## Consequences` shape of the three ADRs beside it, with every rejected alternative recorded alongside the choice that beat it
- Trim #139's technical notes to what an implementer needs at hand plus a citation of the ADR, removing the research prose the record now owns
- Do the same for #207 and #208
- Run the documentation and repository gates named below

## Verification

- `bin/ci`, the repository's one local gate and a superset of its four CI jobs
- The `gh-solo` documentation check, for backticked paths that do not resolve and code fences that do not close
- `gh pr checks` green on `lint`, `scan_js`, `scan_ruby` and `test`

None of those gates can read. They prove the file parses, the paths resolve and nothing else in the repository broke; they say nothing about whether the argument holds, whether each quotation is faithful to the source it names, or whether the three issue bodies genuinely stopped duplicating the record rather than merely getting shorter. That judgement is the owner's, on the diff and on the three issues.

The trim also produces no diff, because an issue body is not a file. Its evidence is the issues themselves, which is why the ADR's last acceptance criterion is written against them rather than against this branch.

## Open questions

None. The design questions were settled in the session that produced the three issues; what is left here is whether the record states them faithfully, which is a review comment rather than an open question.

## Settled

None yet.
