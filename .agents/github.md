# GitHub conventions for this repository

Per-repo overrides for the `github-solo-dev-repo` and `github-pr-flow` skills. Every entry below contradicts a default one of those skills assumes, and this file wins on the conflict. Anything not listed here follows the skills' own standards.

## The only remote is named `upstream`

`git remote` prints exactly one name and it is `upstream`, never `origin`. Any command that hardcodes `origin` fails here, and the first push of a branch is the worst place to discover that, because it fails immediately after the plan commit has already landed. Resolve the remote rather than assuming it; the first push of a branch is:

    git push -u upstream <branch>

## Commit and branch types

`build`, `docs`, `feat`, `fix`, `refactor`, `test`. Six, against the skills' default five.

`build` is the one that differs in substance: it absorbs both `chore` and `ci`, and it accounts for roughly half the commits on `main`. Neither `chore` nor `ci` is a type here. The one `ci:` subject on `main`, 9b0bcc2, is a dependabot squash and was a mistake, which is why `.github/dependabot.yml` now pins the bot's prefix to `build`.

One vocabulary, three places: the branch name, the commit headers on the branch, and the pull request title.

## CI check-run names

`lint` and `test`. Those two, and nothing else.

They are job ids from `.github/workflows/ci.yml`, because no job there sets a job-level `name:`. `main` requires both of them, `enforce_admins` is on, so adding or renaming a job means moving `required_status_checks` in the same change or every open pull request waits forever on a check that never reports.

The two jobs are split on whether the job boots the application. `lint` does not: RuboCop, Brakeman, bundler-audit. `test` does: `bin/importmap audit` and `bin/rspec`.

The local gate is `bin/ci`, a superset of both jobs that also replants the test seeds. Never invent a check command for this repository; it is that one.

## No commitlint and no Node toolchain

There is no commitlint, no npm manifest and no Node anywhere: the front end is importmap, so JavaScript is vendored rather than built. The `scope-enum` rule from the skills review has nothing to run inside and never will while that holds. Type and scope discipline here is a convention a reader enforces, not a hook that does.
