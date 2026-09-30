> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: upgrade herb to 0.11 (#307)

## Approach

`@herb-tools/linter` moves from 0.10.3 to 0.11.0 as an exact pin, `package-lock.json` moves with it, and `node_modules/.bin/herb-lint --upgrade` raises `.herb.yml`'s `version:` to 0.11.0. Measured on this branch: `--upgrade` writes `enabled: false` for `erb-no-multiple-statements` and `html-no-nested-forms` only, and with those two lines removed the six rules the issue names fire 21 times across 20 templates, matching its table. Those two generated lines do not survive: each rule is decided below, and no rule is left off merely because `--upgrade` switched it off.

The calls, rule by rule:

- **`actionview-prefer-qualified-partial-path`, fixed.** `--fix-unsafely` rewrites the nine `render "form"` and `render "form_fields"` calls to their qualified paths. It is unsafe by name, so the gate is that `git diff --stat app/views` names exactly those nine files before the commit.
- **`actionview-no-implicit-partial`, switched off** in `.herb.yml`, because `render @record` is the idiomatic Rails form and the house style's.
- **`actionview-no-helper-shadowing`, fixed.** The confirm sheet's `label:` local becomes `confirm:`, pairing with the `dismiss:` it already takes, which touches its strict-locals line, its two uses and all five callers: `app/views/events/show.html.erb`, `app/views/user_profiles/show.html.erb`, `app/views/styleguides/show.html.erb`, `app/views/members/show.html.erb` and `app/views/groups/edit.html.erb`. In `app/views/layouts/_group_tabs.html.erb` it is a block variable local to the file, which becomes `aria_label`, the one thing it feeds.
- **`actionview-prefer-collection-render`, excluded for `app/views/groups/index.html.erb` only**, rather than switched off as the issue proposed. A collection render cannot pass the per-group `membership`, which the index looks up once so no card queries its own, but the rule is right for any future loop that passes nothing per item, and a rule-scoped `exclude:` is how `html-no-space-in-tag` is already narrowed.
- **`erb-no-multiple-statements`, fixed** by nesting the assignment under an `else` in `app/views/events/_counts.html.erb` rather than hoisting it above the conditional as the issue proposed. `Event#answer_counts` already runs its own grouped count, so hoisting would take the `registrations.size` query on every render where it is now taken only on the branch that prints it.
- **`html-no-nested-forms`, excluded for `app/views/styleguides/show.html.erb` only.** Probed on this branch: the rule fires on any `form_with` inside a `render layout:` block, even with no `<form>` anywhere in the file, so it is an upstream false positive rather than a judgement about the page, and the `.herb.yml` comment names that shape.

No template carries a `herb:disable` comment, per `CLAUDE.md` under *LINTING*. Dependabot #304 closes itself once `main` carries 0.11.0 and is never merged.

## Steps

- Read the `@herb-tools/linter` 0.11.0 changelog for anything beyond the new rules
- Bump `@herb-tools/linter` to 0.11.0 exactly in `package.json`, run `npm install`, then `node_modules/.bin/herb-lint --upgrade`, and drop the two `enabled: false` entries it writes
- Run `node_modules/.bin/herb-lint --fix-unsafely` and keep only the nine qualified partial paths
- Rename the shadowing `label` locals in the confirm sheet, its five callers and the group tabs
- Nest `waiting` under an `else` in `app/views/events/_counts.html.erb`
- Configure `.herb.yml`: `actionview-no-implicit-partial` off, and the two rule-scoped excludes, each with a comment giving the reason
- Commit the bump, the configuration and the template fixes as one `build` commit

## Verification

- `test "$(node -p "require('./package-lock.json').packages['node_modules/@herb-tools/linter'].version")" = "0.11.0" && grep -q '^version: 0.11.0$' .herb.yml` exits 0, having been seen to exit 1 against 0.10.3
- `node_modules/.bin/herb-lint --ignore-disable-comments` exits 0, having been seen to exit 1 with every new rule live and no template changed
- `grep -rn 'herb:disable' app` exits 1, having been seen to exit 0 against a probe template carrying one
- `mise exec -- bin/ci` fails only at *Tests: System*: `test "$(mise exec -- bin/ci 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep '^❌' | cut -d' ' -f2,3)" = "$(printf 'Tests: System\nContinuous Integration')"`, seen to fail on an extra failed step
- The system suite fails only on #299's three examples: `test "$(mise exec -- bin/rspec spec/system --format failures | cut -d: -f1,2 | LC_ALL=C sort -u | tr '\n' ' ')" = "./spec/system/address_edit_page_spec.rb:70 ./spec/system/me_spec.rb:128 ./spec/system/member_edit_page_spec.rb:23 "`, seen to fail on a fourth failure
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-09-30_GHI-307_upgrade-herb.md` exits 0

Herb reads templates statically, so no linter gate sees whether a renamed local or a qualified partial path still renders; that is the request and system specs' job inside `bin/ci`, and a template no spec renders would slip past both. Every shell here runs `bin/ci` through `mise exec --`, because the agent's shell starts on Ruby 4.0.6 while `.ruby-version` names 4.0.7.

## Open questions

None.

## Settled

None yet.
