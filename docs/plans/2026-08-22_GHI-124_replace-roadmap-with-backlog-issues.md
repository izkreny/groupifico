> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Replace the roadmap doc with backlog issues

Plan for #124.

## Context

`docs/ROADMAP.md` and the issue tracker held the same backlog, and the file was the copy that went stale. It listed three items that had already shipped, it was edited on the abandoned `docs-update` branch as well as on `main`, and nothing about it could be filtered, labelled, assigned, blocked or searched.

The extraction has already happened. Every heading in the file is now a sub-issue of the `backlog` epic, #84, which holds 66 children: 60 drafts, one spike, one `bug`, and one fully specified `infra` issue. What is left is the file itself.

Six of those children did not come from the roadmap and are outside this branch's scope. #76, #79 and #83 were already in the tracker. #147 and #148 came from a sweep of `README.md` for intent the roadmap never recorded: the _Coming soon_ list promises notifications, and the ERD block promises a second diagram for authentication once passwordless login lands. #149 holds the work salvaged from the `add_integration_specs` branch, per the settled section below. They are there because the owner wants every open issue parented to the epic, so `#84` now means "all open work" rather than only "what the roadmap held", and the label rather than the parent relation is what separates startable work from a backlog entry. This issue is the one deliberate exception, parented to nothing, because it is the migration itself rather than a thing the migration produced.

**This branch therefore deletes rather than migrates.** The mapping below is the record of where each section went, and it is the reason this plan exists at all: `git log` will show a file being deleted, and a reader six months from now needs to know it was moved rather than abandoned.

### Where each section went

| Section of `docs/ROADMAP.md` | Issues |
|---|---|
| `### Group` | #134, #135, #136, #137, #138 |
| `### User` | #85, #86, #87, #88, #89, #125, #139 |
| `### User Profile` | #90, #135, #140 |
| `### Member` | #91, #92, #93, #126 |
| `### Event` | #94, #95, #96, #97, #98, #99, #100, #101, #127, #128, #135, #141, #142, #143 |
| `### Registration` | #102, #103, #144 |
| `### Address` | #104, #105, #106, #133, #145 |
| `### Links` | #107, #129, #130, #131 |
| `### Song` | #108, #132 |
| `### Polls` | #109 |
| `### Treasury` | #110 |
| `## GENERAL TODO` | #111, #112, #113, #114, #115, #116, #117, #118, #119, #123 |
| `## Web framework` | #120, #121, #122 |

#135 appears three times because the `time_zone` bullets under `### Group`, `### User Profile` and `### Event` are one question about where a time zone lives, not three independent columns.

One bullet is deliberately unmapped. "Duplicate event" is already built as `Event#duplicate`; only its interface is missing, and that is #98.

## Approach

Delete the file, fix the one live link to it, and leave every other mention alone.

**The other mentions are a historical record.** `docs/plans/2026-08-20_GHI-81_consolidate-schema-docs.md` names the file five times, but it is the plan of a merged pull request describing what was true when it ran. Editing it to keep a link alive would falsify the record, and a plan file that no longer matches the PR it planned is worth less than a broken link.

That makes the docs check the one interesting part of this branch. `/home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py` resolves every backticked path in the documents it scans, and both that plan file and this one name `docs/ROADMAP.md` in backticks. Once the file is gone, both fail. The precedent is on this repository already: the #81 branch passed `--ignore 'docs/schema.dbml'` for exactly this, a file it was deleting while its own plan still discussed it.

`README.md` line 24 reads "For more information, check out the detailed [roadmap](./docs/ROADMAP.md)." The sentence exists only to carry the link, and the backlog epic is the thing it should have been pointing at, so it becomes a link to #84 rather than being cut.

## Steps

- Delete `docs/ROADMAP.md`.
- Rewrite `README.md` line 24 so the sentence points at the `backlog` epic, #84, instead of the deleted file, using an absolute GitHub URL since an issue is not a path in the tree.
- Leave `docs/plans/2026-08-20_GHI-81_consolidate-schema-docs.md` untouched, and every other file that mentions the roadmap.

## Verification

Gates, each with an exit code:

- `bin/ci` exits zero. It is this repository's only check command, per its own agent config, and a docs-only branch is expected to leave it green rather than be exempt from it.
- `/home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py`, run with `--root .` and `--ignore 'docs/ROADMAP.md'` over exactly three files, exits zero: `README.md`, this plan, and `docs/plans/2026-08-20_GHI-81_consolidate-schema-docs.md`. Those are every document that names the deleted file, plus the one this branch edits. The ignore covers the two plans' references to it, which is the same allowance the #81 branch took for `docs/schema.dbml`.

  **The file list is scoped deliberately, and pointing the check at `docs/plans/` instead would fail.** `docs/plans/2026-08-19_GHI-72_update-ruby-and-gems.md` line 38 and `docs/plans/2026-08-20_GHI-75_clean-test-database.md` line 20 each backtick a path inside an installed gem rather than in this tree, so the check cannot resolve either. Both failures are identical when the same command runs against `upstream/main`, so they predate this branch and belong to their own change. The #81 plan recorded the same two files failing for the same reason, and this is the second branch to route around them rather than the first. Fixing them means unbackticking paths in the plans of merged pull requests, which falsifies a historical record for a cosmetic gain - the same reason this branch leaves the #81 plan's roadmap references alone.
- `grep -rn -i roadmap README.md` reports nothing, and `git ls-files docs/ROADMAP.md` reports nothing.
- Every issue number in the mapping table above resolves to an open issue whose parent is #84. Checked by a throwaway script in the scratchpad, not committed, reporting both directions: no number in the table that is not a child of #84, and no child of #84 missing from the table except the six non-roadmap issues named in the Context: #76, #79, #83, #147, #148 and #149. Those six are excluded by number rather than by rule, so a seventh appearing later fails the gate and has to be accounted for deliberately. This issue is not a child of #84 and so is not expected in either direction.

Judgement, which no exit code covers:

- **[owner]** The replacement sentence in `README.md` reads as a pointer to live work rather than as an apology for a deleted file.
- **[owner]** The mapping table is honest: each section's issues actually cover what that section said, rather than merely being the right count.

What these gates cannot see: whether a draft's body preserves the intent of the bullet it replaced or only its words; whether the three `time_zone` bullets really are one question, which is an assumption this plan makes and #135 inherits; and whether #149's body preserves everything worth keeping from the `add_integration_specs` branch, which is now the only record of it outside the branch itself.

## Settled while writing this plan

- **`docs-update` and `testing` are deleted, remote and local.** Asking what to do with the stale branches was the plan's one open question, and answering it needed the same audit this branch was already doing. `docs-update` dated from February and predated authentication, every controller and view, every spec, both ADRs and DaisyUI; taking its tree would have removed 4056 lines and reinstated `docs/schema.dbml`. Its salvage landed in #82, and the one bullet that looked branch-only, the `counter_cache` note, is on `main` at `docs/ROADMAP.md` line 59, which is why #133 records the roadmap rather than the branch as its source. `testing` was three lines in `README.md` from a commit-signing experiment. Recovery SHAs, since a deleted branch is only findable if they were kept: `docs-update` remote `3d8400c`, local `0b63d51`, and `testing` `358b4ae`.
- **`add_integration_specs` is deliberately kept.** It holds 150 lines nothing else has: an `AuthenticationHelper` RSpec support module and twelve request examples covering the six user CRUD actions in signed-in and signed-out contexts. Its contents are now recorded on #149 rather than only in the branch, so the next audit does not have to rediscover them the way this one rediscovered `docs-update`'s.

## Open questions

None. The stale-branch question above was settled while this plan was being written.
