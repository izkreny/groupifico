> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Replace the roadmap doc with backlog issues

Plan for #124.

## Context

`docs/ROADMAP.md` and the issue tracker held the same backlog, and the file was the copy that went stale. It listed three items that had already shipped, it was edited on the abandoned `docs-update` branch as well as on `main`, and nothing about it could be filtered, labelled, assigned, blocked or searched.

The extraction has already happened. Every heading in the file is now a sub-issue of the `backlog` epic, #84, which holds 61 children: 58 drafts, one spike, one `bug`, one fully specified `infra` issue, and this one. What is left is the file itself.

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
- `/home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py`, run with `--root .` and `--ignore 'docs/ROADMAP.md'` over `README.md`, `docs/plans/` and this plan file, exits zero: every other backticked path still resolves and every fence is closed. The ignore covers this plan's own references to the file being deleted and the #81 plan's, which is the same allowance the #81 branch took for `docs/schema.dbml`.
- `grep -rn -i roadmap README.md` reports nothing, and `git ls-files docs/ROADMAP.md` reports nothing.
- Every issue number in the mapping table above resolves to an open issue whose parent is #84. Checked by a throwaway script in the scratchpad, not committed, reporting both directions: no number in the table that is not a child of #84, and no child of #84 missing from the table except #124 itself.

Judgement, which no exit code covers:

- **[owner]** The replacement sentence in `README.md` reads as a pointer to live work rather than as an apology for a deleted file.
- **[owner]** The mapping table is honest: each section's issues actually cover what that section said, rather than merely being the right count.

What these gates cannot see: whether a draft's body preserves the intent of the bullet it replaced or only its words; whether the three `time_zone` bullets really are one question, which is an assumption this plan makes and #135 inherits; and whether anything on the unmerged `docs-update` branch still needs salvaging before that branch is deleted.

## Open questions

- **`docs-update` is unmerged and stale.** It carries the `attendees` to `registrations` rename that reached `main` by another route, and its own edit to `docs/ROADMAP.md`. That edit's one net-new bullet is already filed as #133, so nothing on it is lost, but the branch still exists and this is the moment to decide whether it goes.
