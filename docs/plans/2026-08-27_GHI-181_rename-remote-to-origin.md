> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Rename the git remote from `upstream` to `origin`

Closes #181.

## Approach

The rename is one command. The plan exists for the two things around it: the deny rules that name the old remote as a literal string, and the order the two changes land in.

`.claude` is a symlink to `.agents`, so `.agents/settings.json` is the project settings file Claude Code actually reads. Its deny rules are the standing enforcement of "nothing pushes directly to `main`", and they match the literal remote name. The moment the remote becomes `origin`, `git push upstream main` names a remote that does not exist and `git push origin main` matches no rule: the protection does not fail, it stops existing. So the file is edited **before** the rename command runs, and both land in one commit.

Everything else is bookkeeping: the `.agents/gh-solo.md` section that records the remote's name, and a grep to confirm nothing else still means the remote.

## Steps

- Edit `.agents/settings.json`: replace the two `upstream` deny rules with `origin` ones, and add the extra refspec shapes that reach `main` without matching the existing pair (`main:main`, `+main`). The old `upstream` rules are deleted rather than kept alongside; they are dead the moment the remote is renamed, and a dead deny rule is the same silent lie this issue is about.
- Run `git remote rename upstream origin`. Remotes live in the shared config, so the one run covers the `main`, `second` and `third` worktrees together; the two detached worktrees have no upstream to rewrite.
- Confirm `git remote -v` prints `origin` only, and that branch tracking survived: `git config branch.main.remote` and `git rev-parse @{u}` on this branch.
- Rewrite `.agents/gh-solo.md`'s "The only remote is named `upstream`" section. The default no longer needs the override it used to be, but the *per-clone* fact does: the committed files change once, and every machine holding a clone runs `git remote rename` itself. Keep a short section recording that, drop the first-push snippet, which now says only what every tool already defaults to.
- Run the grep sweep and settle the one historical hit (see *Settled* below).
- Tick the issue's acceptance criteria as each verifiably lands.

## Verification

Gates, each with an exit code:

- `git remote` prints exactly `origin`, and `git rev-parse @{u}` resolves on this branch — tracking survived the rename.
- **Each new deny pattern is watched failing before it is trusted.** For every rule added to `.agents/settings.json`, attempt the exact command it names and confirm the harness refuses it. Attempting the command is safe here on two independent counts, both checked rather than recalled: `main` and `origin/main` are at the same commit, so a push that slipped through is `Everything up-to-date`; and `main`'s branch protection has `enforce_admins: true` with required reviews, so the server rejects a direct push anyway. A pattern that does **not** deny is a finding to fix in this change, not a caveat to record.
- `grep -rn upstream` over the tree returns nothing that still means the remote.
- `bin/ci` passes.

What these gates cannot see:

- They cannot prove the deny rules cover *every* way a push can reach `main`. Watching a pattern deny proves that pattern; it says nothing about the shape nobody enumerated. See *Open questions*.
- They cannot cover a clone on another machine. The rename is per clone, and only this one is in reach.

## Settled

**Does the `upstream` hit in `docs/plans/2026-08-22_GHI-124_replace-roadmap-with-backlog-issues.md` have to go?** No. It reads `Both failures are identical when the same command runs against upstream/main`, which is a true statement about what the remote was named when that plan was written. The acceptance criterion asks that nothing *still means the remote*, and a historical record of a past name does not. Editing it would also break the repository's own stated precedent, recorded inside that same plan: rewriting merged plans falsifies a historical record for a cosmetic gain. It stays, and the grep criterion is ticked with that one hit named.

## Open questions

**How tightly should the deny rules match?** The issue raises this and deliberately keeps it out of the acceptance criteria. This plan takes the cheap half — enumerate the refspec shapes that are obvious while the two lines are already open — and defers the rest, because the rest is not a wider pattern but a different mechanism. A prefix-matched string cannot resolve a refspec, so a bare `git push` under a matching refspec, or `git push origin HEAD` while `main` is checked out, reaches `main` without naming it anywhere in the command. Closing that properly means a `PreToolUse` hook that resolves the refspec before allowing the call, which is its own issue rather than a line in this one. Meanwhile `main`'s branch protection is the enforcement that does not depend on enumeration.

## Notes

The plan commit on this branch is pushed as `git push -u upstream <branch>`, under the old name, because the rename is an implementation step that has not happened yet. Every push after it reads `origin`. That is the intended sequence, not a leftover.
