> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Rename the git remote from `upstream` to `origin`

Closes #181.

**Amended on 2026-08-27, after the review round on #190 reversed the second half of the approach.** Superseded text is struck through rather than deleted: the plan being wrong about the deny rules is the useful part of this record, and `## Settled` says what replaced each piece. The rename itself is unchanged.

## Approach

The rename is one command. The plan exists for the two things around it: the deny rules that name the old remote as a literal string, and the order the two changes land in.

`.claude` is a symlink to `.agents`, so `.agents/settings.json` is the project settings file Claude Code actually reads. ~~Its deny rules are the standing enforcement of "nothing pushes directly to `main`"~~ — **wrong, and disproved by this branch: `main`'s branch protection is the enforcement, and `gh-solo` ships a `PreToolUse` hook that resolves a push's destination by parsing the command. The deny rules were only believed to be enforcement.** They do match the literal remote name, and that part holds: the moment the remote becomes `origin`, `git push upstream main` names a remote that does not exist and `git push origin main` matches no rule, so the protection does not fail, it stops existing. That is why the file is touched in the same commit as the rename.

Everything else is bookkeeping: the `.agents/gh-solo.md` section that records the remote's name, and a grep to confirm nothing else still means the remote.

## Steps

- ~~Edit `.agents/settings.json`: replace the two `upstream` deny rules with `origin` ones, and add the extra refspec shapes that reach `main` without matching the existing pair (`main:main`, `+main`).~~ **Superseded: the file is deleted.** The rules were redundant against the hook and, worse, a deny rule names the remote as a literal string, so it goes stale in silence on the next rename — the exact failure this issue exists to fix. See `## Settled`.
- Run `git remote rename upstream origin`. Remotes live in the shared config, so the one run covers the `main`, `second` and `third` worktrees together; the two detached worktrees have no upstream to rewrite.
- Confirm `git remote -v` prints `origin` only, and that branch tracking survived: `git config branch.main.remote` and `git rev-parse @{u}` on this branch.
- ~~Rewrite `.agents/gh-solo.md`'s "The only remote is named `upstream`" section... Keep a short section recording that~~ **Superseded: the section is deleted outright and no section replaces it.** `git clone` names a remote `origin` on its own, so the section recorded a default, which is what that file's header says it is not for. A later commit deleted a second section, `## Pushing to main`, for the same reason. See `## Settled`.
- Run the grep sweep and settle the one historical hit (see `## Settled`).
- Tick the issue's acceptance criteria as each verifiably lands.

## Verification

Gates, each with an exit code:

- `git remote` prints exactly `origin`, and `git rev-parse @{u}` resolves on this branch — tracking survived the rename.
- ~~**Each new deny pattern is watched failing before it is trusted.**~~ **Amended: no deny rule survives, so the gate moved to the layer that does the work.** While the rules existed each was watched refusing the exact command it named, and that is how the `:*` token-matching error was found. The gate that replaced it: the `gh-solo` hook watched firing on `git push origin refs/heads/main`, a shape no deny rule here matched, with the confirmation reaching a human who refused it. Attempting these is safe on two counts, both checked rather than recalled: `main` and `origin/main` were at the same commit, so a push that slipped through is `Everything up-to-date`; and `main`'s branch protection has `enforce_admins: true` with required reviews.
- `grep -rn upstream` over the tree returns nothing that still means the remote.
- `bin/ci` passes.

What these gates cannot see:

- They cannot prove anything covers *every* way a push can reach `main`. Watching one shape deny or ask proves that shape and nothing about the shape nobody tried — which is not hypothetical here: the hook returns no decision at all for `git push origin HEAD` or `git push origin @`, the shape this plan itself named below before anyone measured it.
- They cannot cover a clone on another machine. The rename is per clone, and only this one is in reach.

## Settled

**Does the `upstream` hit in `docs/plans/2026-08-22_GHI-124_replace-roadmap-with-backlog-issues.md` have to go?** No. It reads `Both failures are identical when the same command runs against upstream/main`, which is a true statement about what the remote was named when that plan was written. The acceptance criterion asks that nothing *still means the remote*, and a historical record of a past name does not. Editing it would also break the repository's own stated precedent, recorded inside that same plan: rewriting merged plans falsifies a historical record for a cosmetic gain. It stays, and the grep criterion is ticked with that one hit named.

**How tightly should the deny rules match?** Moved here from `## Open questions`, settled in review, and settled in the opposite direction to the one this plan expected: **not at all, because no deny rule survives.** `gh-solo` already ships the `PreToolUse` hook this plan deferred the question to as unscheduled future work, so there was nothing to schedule. It resolves a push's destination by parsing the command and was measured asking on every shape the rules covered, plus `refs/heads/main`, which none of them matched. The rules were therefore redundant; the reason to delete rather than trim them is that a literal-string rule goes stale in silence on a rename. Neither the issue nor the implementing session checked the plugin's `hooks/` directory or its README before writing six rules to redo that job, which is recorded in the issue's `## Outcome`.

**What did the deny rules leave uncovered, given the hook?** Measured, not assumed: the hook returns no decision for `git push origin HEAD` or `git push origin @`, because its destination parser returns nothing for a bare `HEAD` even though it resolves the same destination for a bare `git push`. With `main` checked out, that shape reaches the trunk with only branch protection behind it. This plan named `git push origin HEAD` as a gap before anything was measured, and it was the one shape still open at the end.

**Was the plan amended after planning time?** Yes, this file, on 2026-08-27, after the round on #190. The header says so and every superseded passage is struck through in place. The precedent is `docs/plans/2026-08-26_GHI-184_update-skill-names.md`, whose `## Settled` records the same kind of rewrite; this plan's own argument against editing plans, in the first entry above, is scoped to plans already merged.

## Open questions

None.

## Notes

The plan commit on this branch is pushed as `git push -u upstream <branch>`, under the old name, because the rename is an implementation step that has not happened yet. Every push after it reads `origin`. That is the intended sequence, not a leftover.
