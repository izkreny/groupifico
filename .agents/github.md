# GitHub conventions for this repository

Per-repo facts for the `github-solo-dev-repo` and `github-pr-flow` skills: the values they tell you to look up here rather than assume, and the places this repository differs from their defaults. This file wins on any conflict. Anything not listed here follows the skills' own standards.

## The only remote is named `upstream`

`git remote` prints exactly one name and it is `upstream`, never `origin`. The skills already treat the remote's name as a per-repo fact and give a recipe for resolving it, so this section overrides nothing; it is the answer that recipe is looking for, recorded once so nothing has to run `git remote` to find it.

The first push of a branch is:

    git push -u upstream <branch>

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

## No commitlint and no Node toolchain

There is no commitlint, no npm manifest and no Node anywhere: the front end is importmap, so JavaScript is vendored rather than built. The `scope-enum` rule from the skills review has nothing to run inside and never will while that holds. Type and scope discipline here is a convention a reader enforces, not a hook that does.
