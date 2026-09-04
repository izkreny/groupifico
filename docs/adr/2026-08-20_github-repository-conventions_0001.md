> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0001. GitHub repository conventions

## Status

Accepted, 2026-08-20. Supersedes nothing.

## Context

The most consequential rules this repository lives by are not files. Branch protection, the enabled merge methods, the sources of a squash commit's subject and body, and the label set all live in the GitHub API. They cannot be committed, they do not arrive with a clone, no diff shows them changing, and `gh api` is the only way to read them back. Issue #73 changed several of them at once.

That is the whole reason this record exists. Without it, a reader of the repository, including a future agent with no memory of the session that set them, sees a `.github` directory and has no way to know that four named status checks gate every merge, that a merge commit is impossible, or that the pull request title becomes the commit subject on `main`.

One person commits to this repository, and that same person is its only reviewer. Every decision below follows from that single fact, and every one of them would need revisiting if a second committer appeared.

## Decision

### Squash is the only merge method

`allow_squash_merge` is true; `allow_merge_commit` and `allow_rebase_merge` are both false. `squash_merge_commit_title` is `PR_TITLE` and `squash_merge_commit_message` is `PR_BODY`, which is the only pairing GitHub accepts that yields `PR_BODY`. `delete_branch_on_merge` is true.

A branch's history is a working record: a plan commit first, then however many commits the work actually took, in the order it took them. `main` is a reading surface. Squashing is what converts the first into the second, and it is why `git log --oneline` on `main` is one line per delivered change rather than one line per keystroke.

The consequence worth stating out loud: **the pull request title is load-bearing**, because it becomes the subject line on `main` with `(#{pr-number})` appended. That is why it carries the conventional type and the layer scope while branch commits carry only the type, and why the type vocabulary recorded in `.agents/gh-solo.md` is enforced at the pull request rather than at the commit.

`delete_branch_on_merge` being true is why a plan file is linked from a pull request body at its path on `main` rather than on the branch: the branch link would rot the moment the thing it documents lands.

### `main` requires `lint`, `scan_js`, `scan_ruby` and `test`, and admins are not exempt

`enforce_admins` is true. Those four are job ids in `.github/workflows/ci.yml` rather than job names, because nothing there sets a job-level `name:`. `strict` is false, so a branch need not be up to date with `main` before it merges.

**All four are pinned to `app_id` 15368, which is GitHub Actions.** A required check stores an app id alongside its name, and that id decides who is allowed to report it. Left unset, anything reporting the right name satisfies the requirement, including a commit status posted straight to the Statuses API from a laptop with a `repo`-scoped token and no work done at all. Pinned, only a check run from Actions counts. Without the pin, `enforce_admins` closes the bypass where an admin merges past a red check, and leaves open the one where a green check is simply asserted; the four names are produced by the workflow and by nothing else, so the pin costs nothing and closes it.

The pin has to be explicit in both directions, because omitting `app_id` does not mean "any app". The API documents omission as "automatically select the GitHub App that has recently provided this check", so a check added without an id silently inherits whoever reported it last. `-1` is the documented value for "explicitly allow any app". This asymmetry was found the hard way, on this branch: removing three checks and adding two back produced two pinned entries and two unpinned ones from identical requests.

**`system-test` is the intended exception, and it is provisional.** When #79 brings that job back, its required check should be added with `app_id: -1` rather than pinned, because a browser suite may be run locally instead of on a runner, with `gh signoff` setting the status by hand; `config/ci.rb` already carries that step commented out. That is a preference to be tested rather than a settled rule: if local signoff turns out not to be worth it, pin `system-test` like the rest and delete this paragraph. `2026-09-04_browser-verification_0005.md` settled it as local signoff, and found that the context `gh signoff` posts is `signoff/<name>`, so that is the required check's name rather than `system-test`.

`enforce_admins` is on for the reason it is usually off: there is one committer, and that committer is an admin. A protection rule an admin may bypass is not a rule, it is a reminder, and it protects the repository exactly as long as the owner remembers it is there. Turning it on costs a real merge that has to wait for a real check, which is the point.

`strict` is false because requiring every branch to be up to date would mean a rebase before every merge, on a repository where branches rarely touch the same files. The price is that a semantic conflict between two branches can land green; the local `bin/ci` run on the branch, and the fact that both branches are the same person's, is what covers that instead.

### Required approving reviews: zero

`required_approving_review_count` is zero, with `dismiss_stale_reviews`, `require_code_owner_reviews` and `require_last_push_approval` all false.

This is not a judgement that review is optional. It is that GitHub cannot express the review this repository actually performs. **GitHub refuses to let an author approve their own pull request**, so with one committer any count above zero is unsatisfiable: the only person who could approve is the one person forbidden from doing so, and `enforce_admins` closes the bypass that would otherwise paper over it. The choice is between zero and a repository where nothing can ever merge.

So the gate moved rather than disappeared. It lives in the `github-pr-flow` merge workflow, which refuses to land a pull request with no review record, and the review itself is the owner reading the diff with the `/code-review` skill on it. What GitHub enforces is that CI passed; what the workflow enforces is that a human looked. Splitting them this way is the only arrangement available, and it is worth knowing that the second half is a convention rather than a server-side rule: it can be skipped by an agent that does not read the skill, and nothing will stop it.

### The layer axis is closed, the rest of the taxonomy arrives on demand, and Dependabot carries none

The **layer axis** is mandatory and closed: `backend`, `frontend`, `fullstack`, `infra`, `docs`, exactly one on everything that is not an epic. That part is the decision.

Every other axis in the standards is **open, and its labels arrive when something needs one**. So the labels that exist today are those five plus `bug`, and that is a snapshot rather than a taxonomy: `spike` on the nature axis, `epic` on the structure axis, and `urgent` and `someday` on the priority axis are all legitimate here and simply have not been wanted yet. `gh issue create` fails on a label that does not exist rather than creating it, so the first issue that needs one is what prompts making it.

`dependencies`, `ruby` and `github_actions` were deleted with #73, and they are not in that category. They were Dependabot's defaults rather than missing values of an existing axis: a second axis running parallel to the layer one, on which a dependency bump is already `infra` work, so labelling it `dependencies` as well answered a question no filter asks.

**Deleting them was not enough, and this is the part worth remembering.** With no `labels` key, Dependabot applies `dependencies` plus an ecosystem label and creates those labels itself if the repository does not have them, so the deletion would have been undone by the next bump. `.github/dependabot.yml` therefore sets `labels: []` on both entries, which is also the correct end state on its own terms: labels belong on issues, never on pull requests, and a Dependabot pull request has no issue to hang a layer on.

`commit-message.prefix` is deliberately not set. Dependabot infers its subject prefix from the patterns already in the repository, and `build` dominates `main`, so pinning it added a line of config to assert something the history already says.

### The CI jobs stay separate, one check per concern

Four parallel jobs: `scan_ruby` runs Brakeman and bundler-audit, `scan_js` runs `bin/importmap audit`, `lint` runs RuboCop, `test` runs RSpec.

**Grouping them was tried in the same pull request that wrote this record, and reverted.** The plan was two jobs split on whether the job boots the application, on the reasoning that only a booting job can fail on a missing native library or a boot-time regression, and that four jobs each repay about fifteen seconds of checkout, Ruby setup and bundle install. Fifteen seconds is real but small, and the grouping cost two things worth much more than that:

1. **A red scan stops the RuboCop cache from saving.** `actions/cache` guards its post step with `success()`, so once Brakeman or bundler-audit shares a job with RuboCop, any failure in them skips the cache save. A lingering gem advisory would mean every push re-runs RuboCop from a cold cache and discards the cache it just built, and on `main` the run-id cache key never gets written at all.
2. **Steps in a job are fail-fast, so a style nit hides the security scans behind it.** Four separate jobs report four independent answers per push. One job reports the first failure and stops, which is strictly less information for the same runner time.

Both are consequences of coupling failures that have nothing to do with each other, which is exactly what separate jobs buy. The parallelism was never the cost; the duplicated setup was, and it was cheap. **Do not group them again.**

### `system-test` was deleted, and it does not come back as a job

The `system-test` job is gone. Its test step was commented out and `spec/` holds model specs and factories only, so it took a runner on every pull request and reported success without running anything: a green check that proved nothing, which is worse than no check, because it reads as coverage.

Its `actions/upload-artifact` step, which kept screenshots from failed system tests, went with it. **Issue #79 brings the suite back the day the first system spec lands, and it runs locally rather than on a runner**, and it is the only thing that will: no gate, no lint rule and no test will notice that day. It returns as a fifth job rather than as steps inside `test`, because a real browser suite runs longer than everything else here and should not sit in front of RSpec's result. The commented-out command it held, `bin/rails db:test:prepare test:system`, was Rails' minitest form and was already wrong for a repository that runs RSpec. `2026-09-04_browser-verification_0005.md` later decided there is no runner job at all: the suite runs locally from `bin/ci` and `gh signoff` reports it.

## Consequences

**Nothing in this repository verifies any of the above.** The settings are outside the tree, so no test fails when they drift. Reading them back:

```sh
gh api repos/izkreny/groupifico --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, squash_merge_commit_title, squash_merge_commit_message, delete_branch_on_merge}'
gh api repos/izkreny/groupifico/branches/main/protection --jq '{checks: .required_status_checks.checks, admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
gh label list
```

**Adding or renaming a CI job is now a two-part change, permanently.** The workflow edit and the `required_status_checks` update have to land together, with the new names read off a real pull request via `gh pr checks` first, and with `app_id` stated rather than omitted, per the pinning section above. Forgetting the second half leaves every open pull request blocked on a check that will never report, and `enforce_admins` means there is no way to merge past it: the recovery is to fix protection, not to force the merge. Issue #79 will hit this, since it adds a fifth job.

**A second committer invalidates the review decision.** The zero-approval argument holds only because the author and the reviewer are the same person. Add a committer and `required_approving_review_count` should become one that same day, at which point the convention half of the gate can be retired.

**The type vocabulary is held by nothing but this record and `.agents/gh-solo.md`.** `build` absorbed `chore` and `ci`, there is no commitlint here and no Node toolchain to host one, and the pull request title is the only place the vocabulary is checked, by a reader. Dependabot's inferred prefix is the one subject nobody writes by hand, and it is inference rather than configuration.
