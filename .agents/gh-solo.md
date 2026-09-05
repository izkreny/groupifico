# GitHub conventions for this repository

Per-repo facts for the `gh-solo` skills that read this file: the values they tell you to look up here rather than assume, and the places this repository differs from their defaults. This file wins on any conflict. Anything not listed here follows the skills' own standards.

## Worktrees

One worktree per issue, created with its branch, at `.claude/worktrees/GHI-{number}/`. That path is the only location Claude Code treats as managed, so entering it never prompts, where a worktree anywhere else prompts on every session. Create it immediately after `gh issue develop`, which is where the branch comes from:

```bash
git worktree add .claude/worktrees/GHI-{number} {branch}
```

The repository root holds the default branch and stays on it. An issue is worked in its own worktree unless the owner says otherwise for that issue. A permanently checked-out trunk is also what the `pr-flow` skill's merge step assumes when it declines `--delete-branch`.

A stack is the exception, and takes one worktree for the whole stack. `gh stack sync` and `gh stack rebase` rewrite every branch in it, and git refuses to move a branch checked out in another worktree, so a worktree per branch fails a cascade rebase partway through and leaves the stack half-moved. The `pr-flow` skill's stack workflow states the same trap from its own side.

A new worktree carries no gitignored state, and needs none for `bin/ci`: its first step is `bin/setup`, and it seeds and resets the test database itself. `config/master.key` is still worth copying in from an existing checkout, because `bin/rails credentials:edit` mints a fresh wrong one rather than failing, and nothing outside production reads credentials to tell you it is missing.

Remove the worktree before deleting the branch, `git worktree remove .claude/worktrees/GHI-{number}`. A branch still checked out somewhere cannot be deleted from the root.

## Commit and branch types

`build`, `docs`, `feat`, `fix`, `refactor`, `test`. Six, against the skills' default five.

`build` is the one that differs in substance: it absorbs both `chore` and `ci`, and it accounts for roughly half the commits on `main`. Neither `chore` nor `ci` is a type here. The one `ci:` subject on `main`, 9b0bcc2, is a dependabot squash and was a mistake.

One vocabulary, three places: the branch name, the commit headers on the branch, and the pull request title.

## CI check-run names

`lint`, `scan_js`, `scan_ruby` and `test`. Those four, and nothing else.

They are job ids from `.github/workflows/ci.yml`, because no job there sets a job-level `name:`. `main` requires all four, and `enforce_admins` is on, so adding or renaming a job means moving `required_status_checks` in the same change or every open pull request waits forever on a check that never reports.

All four are pinned to `app_id` 15368, GitHub Actions, so only a run of the workflow can satisfy them. **State `app_id` when adding a check, never omit it:** omission means "whichever app reported this last", not "any app", and `-1` is the value for "any app". `system-test`, when #79 brings it back, is the intended exception and takes `-1`, because that suite may be run locally with `gh signoff` rather than on a runner.

The four run in parallel and stay separate deliberately. Merging them into one job couples failures that have nothing to do with each other: a RuboCop nit would hide the security scans behind it, and a red scan would stop `actions/cache` saving the RuboCop cache, since its post step is guarded by `success()`. The decision record `docs/adr/2026-08-20_github-repository-conventions_0001.md` has the detail. Do not group them again.

The local gate is `bin/ci`, a superset of all four jobs that also replants the test seeds. Never invent a check command for this repository; it is that one.

## Dependabot carries no labels

`.github/dependabot.yml` sets `labels: []` on both update entries, and that empty list is load-bearing. Labels belong on issues and never on pull requests, and with the key absent Dependabot applies `dependencies` plus an ecosystem label and **creates those labels itself if they do not exist**. Deleting them without the empty list only postpones them to the next bump.
