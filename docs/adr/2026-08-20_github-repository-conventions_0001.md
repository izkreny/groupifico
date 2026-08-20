> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0001. GitHub repository conventions

## Status

Accepted, 2026-08-20. Supersedes nothing.

## Context

The most consequential rules this repository lives by are not files. Branch protection, the enabled merge methods, the sources of a squash commit's subject and body, and the label set all live in the GitHub API. They cannot be committed, they do not arrive with a clone, no diff shows them changing, and `gh api` is the only way to read them back. Issue #73 changed several of them at once.

That is the whole reason this record exists. Without it, a reader of the repository — including a future agent with no memory of the session that set them — sees a `.github` directory and has no way to know that two named status checks gate every merge, that a merge commit is impossible, or that the pull request title becomes the commit subject on `main`.

One person commits to this repository, and that same person is its only reviewer. Every decision below follows from that single fact, and every one of them would need revisiting if a second committer appeared.

## Decision

### Squash is the only merge method

`allow_squash_merge` is true; `allow_merge_commit` and `allow_rebase_merge` are both false. `squash_merge_commit_title` is `PR_TITLE` and `squash_merge_commit_message` is `PR_BODY`, which is the only pairing GitHub accepts that yields `PR_BODY`. `delete_branch_on_merge` is true.

A branch's history is a working record: a plan commit first, then however many commits the work actually took, in the order it took them. `main` is a reading surface. Squashing is what converts the first into the second, and it is why `git log --oneline` on `main` is one line per delivered change rather than one line per keystroke.

The consequence worth stating out loud: **the pull request title is load-bearing**, because it becomes the subject line on `main` with `(#{pr-number})` appended. That is why it carries the conventional type and the layer scope while branch commits carry only the type, and why the type vocabulary recorded in `.agents/github.md` is enforced at the pull request rather than at the commit.

`delete_branch_on_merge` being true is why a plan file is linked from a pull request body at its path on `main` rather than on the branch: the branch link would rot the moment the thing it documents lands.

### `main` requires `lint` and `test`, and admins are not exempt

`enforce_admins` is true. The required status checks are `lint` and `test`, which are job ids in `.github/workflows/ci.yml` rather than job names, because nothing there sets a job-level `name:`. `strict` is false, so a branch need not be up to date with `main` before it merges.

`enforce_admins` is on for the reason it is usually off: there is one committer, and that committer is an admin. A protection rule an admin may bypass is not a rule, it is a reminder, and it protects the repository exactly as long as the owner remembers it is there. Turning it on costs a real merge that has to wait for a real check, which is the point.

`strict` is false because requiring every branch to be up to date would mean a rebase before every merge, on a repository where branches rarely touch the same files. The price is that a semantic conflict between two branches can land green; the local `bin/ci` run on the branch, and the fact that both branches are the same person's, is what covers that instead.

### Required approving reviews: zero

`required_approving_review_count` is zero, with `dismiss_stale_reviews`, `require_code_owner_reviews` and `require_last_push_approval` all false.

This is not a judgement that review is optional. It is that GitHub cannot express the review this repository actually performs. **GitHub refuses to let an author approve their own pull request**, so with one committer any count above zero is unsatisfiable: the only person who could approve is the one person forbidden from doing so, and `enforce_admins` closes the bypass that would otherwise paper over it. The choice is between zero and a repository where nothing can ever merge.

So the gate moved rather than disappeared. It lives in the `github-pr-flow` merge workflow, which refuses to land a pull request with no review record, and the review itself is the owner reading the diff with the `/code-review` skill on it. What GitHub enforces is that CI passed; what the workflow enforces is that a human looked. Splitting them this way is the only arrangement available, and it is worth knowing that the second half is a convention rather than a server-side rule — it can be skipped by an agent that does not read the skill, and nothing will stop it.

### Labels are the layer axis, plus `bug`

The label set is `backend`, `frontend`, `fullstack`, `infra`, `docs`, plus `bug`. `dependencies`, `ruby` and `github_actions` were deleted with #73.

Those three were dependabot's defaults, and they were a second axis running parallel to the first: a dependency bump is `infra` work on the layer axis, and labelling it `dependencies` as well answers a question no filter asks. `.github/dependabot.yml` now applies `infra` directly, and pins the bot's commit prefix to `build` so its squash subjects use the repository's type vocabulary rather than reintroducing `ci:`.

### The CI jobs are grouped by whether they boot the application

`lint` does not boot it: RuboCop, Brakeman, bundler-audit. `test` does: `bin/importmap audit` and `bin/rspec`.

Five jobs became two. The job count was never the expense — each job repays about fifteen seconds of checkout, Ruby setup and bundle install against a warm cache — but only a booting job can fail on a missing native library or a boot-time regression, and that is the one line along which parallelism buys information rather than just runners. The previous branch, #74, is the evidence: a patch-level Rails release added a boot-time `require` and took the whole suite with it, and no static check would have seen it.

The two surviving ids are deliberately the two that already existed. Because protection requires checks by name and the names are the job ids, keeping `lint` and `test` made the protection edit a removal of three contexts with nothing added, and no pull request could be left waiting on a name that had never reported.

### `system-test` was deleted, and it is coming back

The `system-test` job is gone. Its test step was commented out and `spec/` holds model specs and factories only, so it took a runner on every pull request and reported success without running anything — a green check that proved nothing, which is worse than no check, because it reads as coverage.

Its `actions/upload-artifact` step, which kept screenshots from failed system tests, went with it. **Issue #79 carries both back the day the first system spec lands**, and it is the only thing that will: no gate, no lint rule and no test will notice that day. The commented-out command it held, `bin/rails db:test:prepare test:system`, was Rails' minitest form and was already wrong for a repository that runs RSpec.

## Consequences

**Nothing in this repository verifies any of the above.** The settings are outside the tree, so no test fails when they drift. Reading them back:

```sh
gh api repos/izkreny/groupifico --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, squash_merge_commit_title, squash_merge_commit_message, delete_branch_on_merge}'
gh api repos/izkreny/groupifico/branches/main/protection --jq '{checks: .required_status_checks.contexts, admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
gh label list
```

**Adding or renaming a CI job is now a two-part change, permanently.** The workflow edit and the `required_status_checks` update have to land together, with the new names read off a real pull request via `gh pr checks` first. Forgetting the second half leaves every open pull request blocked on a check that will never report, and `enforce_admins` means there is no way to merge past it — the recovery is to fix protection, not to force the merge.

**A second committer invalidates the review decision.** The zero-approval argument holds only because the author and the reviewer are the same person. Add a committer and `required_approving_review_count` should become one that same day, at which point the convention half of the gate can be retired.

**The type vocabulary now has a bot-shaped hole plugged by config.** `build` absorbed `chore` and `ci`, and the only thing that had been emitting `ci:` was dependabot. That is held by two lines in `.github/dependabot.yml` rather than by anything that checks commit subjects, since there is no commitlint here and no Node toolchain to host one.
