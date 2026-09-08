> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: lint erb templates with herb (#241)

## Approach

Every number below was measured on this branch against `@herb-tools/linter` 0.10.3 before the plan was written, the way #262's plan was, and then reverted so this commit lands alone. Four of the claims correct the issue's technical notes.

**The templates are already almost clean, and the offenses are not where the issue expects.** A default run checks 54 files with 85 rules enabled and reports 11 offenses across 6 of them. Ten are errors and every one is `html-no-space-in-tag` in the five tracked static error pages under `public/`, at the same place in each: a missing space before `/>` inside a minified inline `<svg>` that Rails generated. Exactly one offense is in `app/views/`, `erb-no-commented-out-output-tags` at `app/views/layouts/application.html.erb:15`, and it is real: the PWA manifest `<%#= tag.link … %>` line is a commented-out output tag. So 48 of the 49 templates the redesign will rewrite are clean today, and the issue's expectation of a backlog to clear first does not survive measurement.

**54 files, not 49, because `**/*.html` is in the default include set.** The five that pushed the count up are `public/400.html`, `public/404.html`, `public/406-unsupported-browser.html`, `public/422.html` and `public/500.html`, all tracked. Everything else lands as the issue assumes: all 49 `.html.erb` templates match, and the five templates that are not HTML fall outside the include set on their own, so nothing has to be written to keep an HTML-aware linter off a `.text.erb` mail body or off `app/views/pwa/manifest.json.erb`.

**The `public/` errors get a rule-scoped exclude rather than a fix.** `--fix` clears all ten and was tried; its diff inserts one space before `/>` inside a 6000-character minified SVG path in each file, which no reader benefits from and which `rails new` reintroduces on the next framework upgrade, making the gate red for something nobody on the branch did. Excluding `public/**/*` from that one rule keeps the other 84 running on pages users actually see, which a directory-wide exclude would not.

**Discovery honours `.gitignore`, so the managed worktrees need no exclude.** Worth establishing rather than assuming, because `.agents/gh-solo.md` puts every issue's worktree inside the repository and Herb's default excludes name `coverage`, `log`, `node_modules`, `storage`, `tmp` and `vendor` but not that path. A probe file written under a gitignored path was not picked up and the count stayed 54.

**`.herb.yml` carries a `version:` key, and it is the inverse of `NewCops: enable`.** Rules introduced after the version recorded there stay off until it is bumped, and `--upgrade` bumps it while writing an explicit `enabled: false` for each newly arrived rule. That is a real trap for this repository, whose `.rubocop.yml` opts into new cops on purpose: a Dependabot bump of the package alone leaves the new rules silently inactive. The bump procedure belongs beside the key, and `--disable-failing`, which writes an `enabled: false` for every rule that currently has an offense, is the shape to stay away from for the same reason.

**`failLevel` is set to `hint`, the strictest setting, rather than left at its `error` default.** With the `public/` exclude in place the only remaining offense is that one `info`, and at the default it would fail nothing: the gate would go green over a template the linter is complaining about. Measured both ways - `failLevel: hint` exits 1 on it, and exits 0 across all 54 files once the two dead PWA lines are deleted. That matches what `bin/rubocop` already does here, where no offense is tolerated.

**Herb has an inline suppression comment, `<%# herb:disable %>`, and this repository's existing policy already answers it.** `CLAUDE.md` forbids an inline `rubocop:disable` outright and `bin/rubocop` passes `--ignore-disable-comments` so the ban has no exception; the linter takes a flag of the same name and meaning. Both call sites pass it, so the directive is inert here and a rule that bites is a conversation rather than a comment. The rules Herb ships about the directive, `herb-disable-comment-missing-rules` and its siblings, police its syntax rather than its use, so they are not a substitute for the flag.

**The gate calls `node_modules/.bin/herb-lint`, not `npx herb-lint`.** That path is the binary the package installs and what a wrapper resolves to anyway, so calling it leaves no resolution step between the pinned version and the run, where a bare name is free to reach past the pin. It is also the one shape that behaves identically in both call sites. This departs from the first acceptance criterion's literal wording and is the one amendment the issue needs. `--github` needs no flag either: the linter detects GitHub Actions on its own, which is what `--no-github` exists to switch off.

## Steps

- Hand-write `package.json` pinning `@herb-tools/linter` to `0.10.3` and install per that manifest, then commit it with `package-lock.json`, `/node_modules` added to `.gitignore`, and `.node-version` holding `24` so `actions/setup-node` and the local toolchain read one pin and a patch release needs no repository edit
- Commit `.herb.yml`: `version: 0.10.3`, `framework: actionview`, `linter.failLevel: hint`, and `html-no-space-in-tag` scoped with `exclude: ['public/**/*']`. Each carries a comment saying why, as `.rubocop.yml` does, and the `version` key's comment carries the bump procedure so a Dependabot pull request is not merged leaving new rules off. `--init` also writes `.vscode/extensions.json` recommending the Herb LSP, which lands beside the `.vscode/settings.json` this repository already tracks and is worth keeping
- Delete the two dead PWA lines from `app/views/layouts/application.html.erb`, the commented-out `<%#= tag.link … %>` output tag and the note above it that points at it, collapsing the blank line the removal leaves. The commented-out route in `config/routes.rb` that the note mentions is left alone and wants its own issue
- Add `step "Style: ERB", "node_modules/.bin/herb-lint --ignore-disable-comments"` to `config/ci.rb` beside `step "Style: Ruby"`, and an install step to `bin/setup` so `bin/ci`'s first step leaves the binary on disk for the step that needs it
- Add `actions/setup-node` with `node-version-file: .node-version` and `cache: npm`, then `npm ci`, then the same command, to the existing `lint` job in `.github/workflows/ci.yml`. Inside that job, so the required check names stay `lint`, `scan_js`, `scan_ruby` and `test` and branch protection is untouched
- Add an `npm` entry to `.github/dependabot.yml` carrying `labels: []`, for the reason that file's own comment gives
- Extend the inline-disable ban in `CLAUDE.md`'s linting section to `herb:disable`, in one sentence beside the `rubocop:disable` rule it already states, since that is where the same policy is already written down
- Watch the gate fail before trusting it: commit a template carrying an unquoted attribute and an unclosed tag, with a `<%# herb:disable %>` comment on the offense, and confirm it goes red both locally and on GitHub despite the comment. Then remove the offense in the next commit and watch both go green

## Verification

- `bin/ci` exits 0
- `node_modules/.bin/herb-lint` reports 54 files checked and 0 offenses, having been seen to report 11 offenses across 6 files before `.herb.yml` and the layout fix landed
- The deliberate-offense commit exits 1 locally and leaves `lint` red on GitHub, and still exits 1 with a `<%# herb:disable %>` comment on the offense, which is `--ignore-disable-comments` seen working rather than assumed
- `gh pr checks` reports `lint` passing again after the commit that removes the offense, which is the CI call site proven separately from the local one, since its install path is different and can be broken while the local run is green
- `gh api repos/{owner}/{repo}/branches/main/protection --jq '.required_status_checks.contexts'` still returns exactly `lint`, `scan_js`, `scan_ruby` and `test`
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore 'docs/plans*' --ignore '.agents/*' --ignore '.herb.yml' --ignore '.vscode/extensions.json' --ignore 'package*.json' --ignore 'lib/herb/*'` exits 0 over this plan

Three things no gate here can see. Whether 85 rules is the right *policy* for this application is a judgement, and the gates only prove that whatever is enabled is applied and that a malformed template reaches it. Whether the redesign rows keep the templates clean is the whole reason the issue wants this landed before the first one is written, and nothing on this branch can prove it: a linter lands a floor, not a habit. And the `version` key means an unbumped `.herb.yml` reports green on a rule set that is quietly out of date, which is visible by reading the file rather than by running it.

## Open questions

None.

## Settled

- **Is the Node toolchain accepted, given ADR 0005?** Yes, and the split is that the repository's own manifest is what the gate resolves through, while anything installed machine-wide is for ad-hoc use and editor integration only. `docs/adr/2026-09-04_browser-verification_0005.md` counted a Node toolchain against Playwright and that cost is real, but there is no Herb without it: the `herb` RubyGem at the same 0.10.3 version is parser bindings, giving `Herb.parse` and no linter, and the pure-Ruby alternatives, `erb_lint` 0.9.0 and `erblint-github` 1.0.1, are different tools with different rules rather than a Herb without Node.

- **`npx herb-lint`, as the first acceptance criterion says?** No: `node_modules/.bin/herb-lint`, for the reason the Approach gives. This is the one place the issue's criteria need amending, and the body is not edited from inside this chain, so it is named here for the owner the way #262 named its own.

- **Do `actionview-*`, `turbo-*` and `ujs-*` stay on?** Yes, at their defaults, and the question turned out to be cheap: none of them fires on any of the 54 files. A rule with no offenses costs nothing to leave enabled, and disabling one pre-emptively would record no reason.

- **`framework: actionview` or the `ruby` default?** `actionview`, because it is true of this application. Measured to change nothing here, the same 85 rules and the same 11 offenses either way, so it is a declaration rather than a fix, and stating it is what keeps the ActionView rules correct as they grow.
