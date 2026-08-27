> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: rename .agents/github.md to .agents/gh-solo.md (#184)

## Approach

`gh-solo` 2.0.0 reads its per-repo config from `.agents/gh-solo.md`, falling back to `.claude/gh-solo.md`, and contains no reference to `.agents/github.md` anywhere. So the file this repository keeps its GitHub conventions in is invisible to the flow that reads them: the remote's name, the CI check-run names, the commit and branch type vocabulary, and `bin/ci` as the one local gate. Nothing errors, which is what makes it worth a branch. The skills find no file and start asking for facts that are already written down, and a flow that refuses to invent check commands has nothing to refuse from.

The rename is the deliverable. The stale opening line this issue started as rides along in the same edit, because it is the same sentence a reader reaches first. Every other fact in the file stays true and stays where it is, and `.claude/gh-solo.md` resolves for free through the existing symlink.

Two things follow from the move rather than from the edit. Inbound links have to move with it, in `AGENTS.md` twice and in `.agents/testing.md` once, where the link text and the target differ and both are wrong after the move. And the docs check needs `--ignore '.agents/github.md'` from here on, because `docs/plans/` and `docs/adr/` name the old path in several places and every one of them is a record of what was true when it was written. That is the allowance #81 and #124 each took for a file they were deleting.

## Sequence outside this repository

None of this is repository work and none of it is an agent's to do, an install being owner-gated in any case. The branch waits on it rather than driving it, in this order:

1. Install and enable `gh-solo` 2.0.0.
2. Confirm the owner-facing skills resolve under their new names: `gh-solo:tracker`, `gh-solo:pr-flow`, `gh-solo:implement`. The `reviewer` skill is loaded by the agent a review round spawns, never typed.
3. Remove the pre-plugin standalone skills the plugin replaces, and the retired implementer agent definition with them. 2.0.0 deleted that agent on purpose: review is the subagent now, because it needs a context that has not already reasoned its way to why the code looks the way it does, and implementation is the opposite case and runs in session.
4. Say so on this PR, and the merge follows.

Install before remove is the part worth stating. The two name sets do not collide, so while both exist the old names keep working and there is no window where the flow this repository depends on is unavailable.

One consequence of that window is worth knowing rather than fixing: between the install and this merge, 2.0.0 cannot see this repository's conventions, because the file it looks for does not exist yet. Expect the flow to ask for the remote's name and the check command during exactly the branch that makes them readable again. This PR closes that gap; nothing else needs to.

## Steps

- `git mv .agents/github.md .agents/gh-solo.md`, so history follows the file
- Rewrite the opening line to name the `gh-solo` skills collectively, naming no individual skill, and leave the rest of the sentence and every other section untouched
- Repoint the inbound links: `AGENTS.md` twice, `.agents/testing.md` once, link text and target both

## Verification

- `bin/ci` passes on this branch
- The suite's docs check passes over `AGENTS.md`, `.agents/`, `docs/adr/` and this plan file, run with `--root .`, `--ignore '.agents/github.md'` and `--ignore '~/Projects/examples/rails/'`, which covers the historical records, this plan's own account of the old name, and one pre-existing unresolvable span in `AGENTS.md` that predates this branch
- `grep -rIn 'github\.md' --exclude-dir=.git .` returns hits only under `docs/plans/` and `docs/adr/`
- [owner] `gh-solo` 2.0.0 is installed and enabled and the pre-plugin suite is gone, before this merges

A docs-only diff gives `bin/ci` almost nothing to catch, and the grep proves only that a string is absent from the live files. What none of these gates can see is whether the renamed file is actually the one 2.0.0 picks up in this repository; the first tracker or PR command that quotes this repo's own check command back is what answers that, which is why the last box is the owner's.

## Open questions

None.

## Settled

- Should the branch and this plan file lose the `update-skill-names` slug the scope outgrew? No. They match each other, which is the only constraint the format imposes, and renaming a branch under an open pull request trades a live PR association for cosmetics. Settled in the terminal, 2026-08-27.
- Should this file name the skills at all? No individual skill is named. The opening line becomes `Per-repo facts for the `gh-solo` skills that read this file: the values they tell you to look up here rather than assume, and the places this repository differs from their defaults.` The argument for keeping the identifiers was precision, and checking the plugin killed it: all four of its skills read this file, the line it carried named two, so the enumeration was already understating by half before either rename made it stale. After the move the filename carries the binding, and a divergence between filename and plugin fails loudly where a stale enumeration inside the file does not.
- Rewritten on 2026-08-27, after `gh-solo` 2.0.0 landed. The original plan covered one stale line, on the premise that the plugin had only renamed its skills. 2.0.0 also renamed the per-repo config file it reads, which turns a cosmetic edit into a silent loss of every convention this repository records, so the file rename became the deliverable and the line became part of it.
- The sequence step that waited on unfinished plugin changes is gone: 2.0.0 has landed and is tagged.
- No `Reviewer agent:` line is added. 2.0.0 lets a repository appoint its own reviewer in this file, and this one wants the reviewer the plugin ships, which is what an absent line already means.
