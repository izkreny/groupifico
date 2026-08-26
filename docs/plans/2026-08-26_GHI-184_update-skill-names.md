> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update the skill names in .agents/github.md (#184)

## Approach

One line changes. `.agents/github.md` opens by naming the two skills it serves, and both were renamed when the GitHub suite moved into the `gh-solo` plugin: they are `gh-solo:tracker` and `gh-solo:pr-flow` now. Nothing else about the contract moved, so nothing else in the file is false: the skills still look for this file at this path, `.claude/github.md` still resolves here through the symlink, and the sections that say "the skills" generically stay correct as written.

The interesting part of this branch is not the edit, it is the ordering. The file describes the owner's agent space, and the sentence this branch writes is only true once the renamed skills are the ones actually in use there. Merging first would swap one false line for another, so the sequence below gates the merge rather than the branch.

Old references elsewhere in the tree are deliberately left alone. `docs/plans/` and `docs/adr/` name the predecessors too, four of the plan files through an absolute path to the earlier copy of the suite's docs check, and every one of those is a record of what was true when it was written. None of them breaks either: that check skips any backticked span beginning with `/`, so a path that stops resolving is a path it never resolved in the first place.

## Sequence outside this repository

None of this is repository work, none of it is an agent's to do, and an install is owner-gated in any case. The branch waits on it rather than driving it, in this order:

1. Finish the outstanding changes to the `gh-solo` plugin, so the names this branch records are the ones the plugin ships.
2. Install and enable the plugin, then confirm the three skills resolve under their new names: `gh-solo:tracker`, `gh-solo:pr-flow`, `gh-solo:implement`.
3. Remove the standalone predecessors the plugin replaces, the retired agent definition included, so no name resolves to two definitions.
4. Say so on this PR, and the merge follows.

Step 2 before step 3 is the part worth stating: while both exist the old names still work, and there is no window where the flow this repository depends on is unavailable.

## Steps

- Rewrite the opening line of `.agents/github.md` to name `gh-solo:tracker` and `gh-solo:pr-flow`, leaving the rest of the sentence and every other section untouched

## Verification

- `bin/ci` passes on this branch
- The suite's docs check passes on this plan file and on `.agents/github.md`
- `grep -rn 'github-solo-dev-repo\|github-pr-flow' .agents/` returns nothing
- [owner] The renamed skills are installed and enabled, and the standalone predecessors are gone, before this merges

A docs-only diff gives `bin/ci` almost nothing to catch, and the grep proves only that two strings are absent. What none of these gates can see is whether the names now in the file are the names that actually resolve in the owner's agent space; invoking the skills is what answers that, which is why the last box is the owner's.

## Open questions

- Should this file name the skills at all? Naming them buys precision and costs a line that goes stale on every rename, which is what produced this issue. Wording it as "the GitHub workflow skills that read this file" cannot go stale, and matches the rule against copies that nothing invalidates. My recommendation is to keep the identifiers: the file is the per-repo half of a two-file contract, and a reader who cannot tell which skills it binds cannot tell whether it still binds anything. A rename is cheap and rare; ambiguity about the contract is neither. If the answer is the generic wording instead, the issue's acceptance criteria change with it.

## Settled

None yet.
