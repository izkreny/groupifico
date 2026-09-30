> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update outdated packages (#274)

## Approach

Three ecosystems move in one round, toolchain first: Ruby 4.0.7 and RubyGems with Bundler 4.0.21 are already installed on the owner's machine, so the repository only has to name them, in `.ruby-version`, the `Dockerfile`'s `ARG RUBY_VERSION` and `Gemfile.lock`'s `BUNDLED WITH`. The version is named explicitly, `bundle update --bundler=4.0.21`, for the trap `.agents/dependencies.md` records. Every Ruby command on this branch runs as `mise exec -- <command>`, because the agent's shell was started with the 4.0.6 install on its `PATH` and only `mise exec` resolves the worktree's `.ruby-version`.

The gems follow `.agents/dependencies.md`'s order with `--conservative`. Rails 8.1.4 and the other minor and patch releases land together, since nothing among them is a major. `json` 3.0 is the one major, so it lands in its own commit with the unpin. That commit happens only after the installed `activesupport` has been read and shown to pass `**options` to `JSON.parse`, which the `v8.1.4` tag does. `diff-lcs` and `marcel` stay held upstream and are not touched.

`@herb-tools/linter` moves from 0.10.3 to 0.11.0 as an exact pin, matching how `package.json` pins it today, and `package-lock.json` moves with it. `.herb.yml`'s own comment says the package bump alone leaves new rules inactive: `herb-lint --upgrade` raises its `version:` and writes an explicit `enabled: false` for each newly arrived rule, and each of those is then decided on its own. Here that means switching each one on. Where a new rule fires on an existing template, the template is fixed if the rule is right about it, and the rule is raised with the owner if it is wrong for this repository. An inline `herb:disable` is never the answer. RuboCop 1.91 and rubocop-rails 2.38 get the same treatment through `NewCops: enable`.

GitHub Actions, the importmap pins and Node need nothing, per the issue's technical notes. Dependabot pull requests #291, #302, #303, #304 and #305 all close themselves once `main` carries the versions.

## Steps

- Read the changelogs that can change behaviour: Rails 8.1.4, json 3.0, net-protocol 0.4, `@herb-tools/linter` 0.11, RuboCop 1.91 and rubocop-rails 2.38
- Set `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION` to 4.0.7, install the bundle under it, then `bundle update --bundler=4.0.21`, as one toolchain commit
- Bump every minor and patch release in one commit: `bundle update --conservative` naming rails and its component gems, annotaterb, image_processing, solid_cable, rubocop, rubocop-rails, bigdecimal, fugit, io-console, msgpack, net-imap, net-protocol, net-smtp, rdoc, regexp_parser, unicode-display_width and unicode-emoji
- Read `JSON.parse` in the installed `activesupport` gem's JSON decoding file, then in a commit of its own drop the `json` pin and its comment from `Gemfile`, run `bundle update --conservative json`, and remove `json` and its *Check the installed gem* paragraph from `.agents/dependencies.md`, along with the *Held by this repository's own `Gemfile`* passage that has nothing left to hold
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems and `BUNDLED WITH` moved
- Bump `@herb-tools/linter` to 0.11.0 exactly, run `node_modules/.bin/herb-lint --upgrade`, switch each newly arrived rule on, and fix or raise whatever fires, in one commit
- Fix whatever the new RuboCop cops flag in existing code, or raise it with the owner, in its own commit if any fires

## Verification

- `mise exec -- bin/ci` passes, browser suite included
- `mise exec -- bundle outdated rails annotaterb image_processing solid_cable json rubocop rubocop-rails net-protocol` exits 0, having been seen to exit 1 before the bumps
- `test "$(grep -A1 '^BUNDLED WITH' Gemfile.lock | tail -1 | tr -d ' ')" = "4.0.21"` exits 0, having been seen to exit 1 against the locked 4.0.20
- `test "$(cat .ruby-version)" = "4.0.7" && grep -q '^ARG RUBY_VERSION=4.0.7$' Dockerfile` exits 0, having been seen to exit 1 against `Dockerfile` before its edit
- `grep -q 'JSON.parse(json, \*\*options)' "$(mise exec -- bundle show activesupport)/lib/active_support/json/decoding.rb"` exits 0, having been seen to exit 1 against the installed 8.1.3.1
- `grep -q 'gem "json"' Gemfile` exits 1, having been seen to exit 0 while the pin is there
- `grep -q '^- \*\*`json`\*\*' .agents/dependencies.md` exits 1, having been seen to exit 0 while the entry is there
- `test "$(node -p "require('./package-lock.json').packages['node_modules/@herb-tools/linter'].version")" = "0.11.0" && grep -q '^version: 0.11.0$' .herb.yml` exits 0, having been seen to exit 1 against 0.10.3
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-09-30_GHI-274_update-outdated-packages.md .agents/dependencies.md` exits 0

No gate here sees what json 3.0 or Rails 8.1.4 changed outside the paths the specs reach, so a serialization or framework difference in an untested path is invisible to every box above. Nothing builds the Docker image either, so the `ARG RUBY_VERSION` bump is unverified until a deploy does, which is why the first deploy after this lands is worth watching. Bare `bundle outdated` stays at exit 1 for as long as `diff-lcs` and `marcel` are held, so the lockfile is read by eye for everything the named-gem gate does not cover. Dependabot's self-close happens on `main` after the merge, and is checked there.

## Open questions

None.

## Settled

- **Ruby counts as a package in this round**, as it did in #72, and the owner installed 4.0.7 and ran `gem update --system` by hand on 2026-09-30.
- **Herb's upgrade includes `.herb.yml`'s `version:`**, so the rules 0.11 adds are decided rather than left inert behind the old rule-set lock.
- **The whole round is one issue**, because every ecosystem shares the one `bin/ci` gate and the owner calls it one update context.
