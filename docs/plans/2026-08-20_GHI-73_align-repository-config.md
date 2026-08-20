> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: align repository config with the github conventions

Issue: #73

## Context

Six acceptance criteria, one of which can block every pull request on the repository if it lands in the wrong order. Everything else here is a file edit or a `gh` call, so the plan is mostly about sequence.

The blocking one is the CI regrouping. Branch protection requires status checks *by name*, and with no job-level `name:` in `.github/workflows/ci.yml` the names are the job ids. `main` currently requires five of them and `enforce_admins` is on, so there is no bypass: the moment this branch stops producing `scan_ruby`, `scan_js` and `system-test`, its own pull request waits forever on three checks that no longer report, and so does every other open branch.

Two decisions were taken before writing this, and both narrow the work:

- **The two jobs keep the ids `lint` and `test`.** The non-booting group takes over `lint`, the booting group takes over `test`, so the protection edit is a pure removal of three contexts and adds none. No pull request can ever wait on a name that never existed, which is the whole failure mode above. The cost is that a reader of the workflow sees a job called `lint` running Brakeman and bundler-audit; a comment in the file carries the reasoning.
- **`system-test` is deleted rather than kept as a stub.** Its test step is commented out and `spec/` holds model specs and factories only, so it consumes a runner per pull request and reports success without running anything. Its one live step, the failure-screenshot upload, is meaningless without system specs and belongs with them. System specs are expected soon, so the decision record has to say plainly what to restore and where it went.

The two dependabot pull requests that held the three doomed labels, #70 and #71, are already closed, both superseded by dbc7409, which put `main` ahead of the versions they proposed. Nothing blocks the label deletion any more.

## Steps

- Commit the agent config that is already in the working tree: `.agents/settings.json` and the `.claude` symlink. Confirm git stored the symlink as a symlink and not as a copied directory, since a directory here would shadow the real one on every checkout
- Add `labels: [ "infra" ]` to both update entries in `.github/dependabot.yml`, so dependabot stops minting its own axis and uses the layer taxonomy the tracker already has
- Delete the `dependencies`, `ruby` and `github_actions` labels, now that no open pull request carries them
- Regroup `.github/workflows/ci.yml` into two jobs split on whether the job boots the application: `lint` gets `bin/rubocop`, `bin/brakeman` and `bin/bundler-audit`, `test` gets `bin/importmap audit` and `bin/rspec`. Delete the `system-test` job. Keep the RuboCop cache step in `lint`, and change nothing about how any command is invoked, so a failure after this can only be the grouping
- Write `.agents/github.md` recording the four per-repo overrides, **after** the workflow edit rather than before, because the third override is the list of check-run names and the point of the file is to be true
- Write the decision record at `docs/adr/2026-08-20_github-repository-conventions_0001.md`, creating `docs/adr/`: squash-only merges, the required check list, why the required approving review count is zero, and what `system-test` took with it when it went
- Push, read the new check names off the pull request with `gh pr checks`, then set branch protection's required checks to exactly those two. In that order, and before merging anything

## Verification

Gates with an exit code, each the implementing agent's to run and tick:

- `bin/ci`, which is setup, RuboCop, bundler-audit, importmap audit, Brakeman, RSpec and a seed replant in sequence
- `gh pr checks <pr-number>` listing exactly `lint` and `test`, both green, after the workflow change is pushed
- `python3 /home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py` over this plan and the decision record
- `git ls-files -s .claude` reporting mode `120000`
- `gh label list` no longer printing `dependencies`, `ruby` or `github_actions`
- `gh api repos/izkreny/groupifico/branches/main/protection --jq '.required_status_checks.contexts'` returning `["lint","test"]`

What those gates cannot see, and what therefore needs judgement:

- **Nothing verifies the boots-the-app split itself.** It is a reading of what each command loads: `bin/importmap audit` and `bin/rspec` go through `config/environment.rb`, RuboCop parses files, Brakeman analyses statically and bundler-audit reads `Gemfile.lock`. A gem that moves a check from one side of that line to the other would not fail anything, it would just make the grouping a lie.
- **Deleting `system-test` deletes the screenshot-artifact step with it.** No gate will notice the day system specs arrive, so the decision record is the only thing that will say what to put back.
- **Branch protection and the label set are GitHub-side state, not files.** They are outside the diff, nothing in the repository can drift-check them, and the decision record exists precisely because they cannot be committed.
- **`bin/ci` green says nothing about controllers or views.** There are no request, system or integration specs; coverage stops at models, exactly as recorded on the previous branch.

## Open questions

- **Resolved.** The decision record is the repository's first, and `docs/adr/` did not exist yet. The filename carries the day the record was written, `2026-08-20`, rather than the `2026-08-19` issue #73 named, and that issue's fifth acceptance criterion was edited to match rather than left pointing at a path nothing would create.
- Restoring `system-test` alongside the first system specs is recorded in the decision record, which is durable but passive. Should a follow-up issue carry it instead, so it appears in the tracker rather than only in prose?
