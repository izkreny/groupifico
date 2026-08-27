# GitHub conventions for this repository

Per-repo facts for the `gh-solo` skills that read this file: the values they tell you to look up here rather than assume, and the places this repository differs from their defaults. This file wins on any conflict. Anything not listed here follows the skills' own standards.

## Pushing to `main`

Three things carry the standing rule that nothing pushes directly to `main`, and they are worth telling apart, because only one of them actually holds.

`main`'s **branch protection** is the enforcement. It is a server-side rule on the ref, so it does not care how a push is spelled: a pull request is required, `enforce_admins` is on, and the four checks below must pass. A repository without this has no enforcement of the rule, only a convention.

`gh-solo` ships a **`PreToolUse` hook** of its own, which parses the command and resolves the destination properly rather than matching text. It decides *ask* rather than *deny*, on purpose, since it fires in every repository and plenty are legitimately trunk-only. Two consequences: an unattended session can answer that ask without a human, and the hook fails open on a destination it cannot resolve statically, such as a variable or an `eval`.

The single **deny rule** in `.agents/settings.json` is neither of those. It is a local convenience that stops an agent attempting the obvious spelling, and it names the remote literally, so **renaming the remote is a change to that rule, in the same commit**: a rule naming a remote that no longer exists does not fail loudly, it stops existing. It is deliberately one rule rather than a list of spellings, because a longer list of literal strings reads as more protective without being so, and the hook already covers the shapes such a list would chase.

## Worktree folders

For development, clone the repository into a folder named `main` inside a dedicated project folder, for example `~/Projects/groupifico/main`, so the worktrees for the parallel streams land beside it as siblings: `second`, with `third` to come when two streams feel comfortable. Each folder hosts one issue's branch, or a `gh stack` of dependent branches, at a time, and is reused across issues; never create a folder per branch. The decision record is the beta-scope spike plan, `docs/plans/2026-08-23_GHI-150_beta-scope-ai-harness.md`.

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
