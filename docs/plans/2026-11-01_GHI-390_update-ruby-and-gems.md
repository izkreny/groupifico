> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update ruby to 4.0.9 and outdated gems (#390)

## Approach

The toolchain moves first. `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION` both name 4.0.9 in one commit, and `mise exec -- bundle install` then rebuilds the project's gems under it. `BUNDLED WITH` already carries 4.0.23, so `bundle update --bundler` is skipped. Every Ruby command on this branch runs as `mise exec -- <command>`, so the worktree's `.ruby-version` decides the version.

The gems follow with `--conservative`. cuprite 0.20 and ferrum 0.20.1 move in their own commit, since they are 0.x minors that drive the browser suite and cuprite 0.20 requires `ferrum (~> 0.20.1)`. Every other gem in the round is a minor or a patch inside its constraints and moves in one commit: addressable 2.9.2, annotaterb 4.26.0, bootsnap 1.26.1, crass 1.0.8, io-console 0.9.5, msgpack 1.8.7, net-scp 4.2.0, net-sftp 4.1.1, net-ssh 7.3.8, parser 3.3.13.0, rack 3.2.8, rubocop 1.92.2, sqlite3 2.10.2 and tailwindcss-rails 4.7.0. `diff-lcs`, `marcel` and `prism` stay where they are, and `net-ssh` stays below 8.0, all held upstream.

`execute_async_script` in `spec/support/axe.rb` calls `browser.evaluate_async`, which ferrum's unreleased 0.21 removes, and scripts passed to `evaluate_script` and `execute_script` may warn about ferrum 0.21. A warning the specs' own scripts trigger is adapted in the cuprite commit, which *What an update round may fix* in `.agents/dependencies.md` allows at any size.

rubocop 1.92.2 may enable new cops, since `.rubocop.yml` sets `NewCops: enable`. A new offense is fixed where the cop is right, and stops the round for the owner where it is not, per the linting rules in `CLAUDE.md`.

Step 1 of the update order in `.agents/dependencies.md` is rewritten in its own commit, because the owner's run showed that `mise upgrade --bump` cannot write `.ruby-version`.

## Changelog impact

tailwindcss-rails is the only package in the round that ships anything near the app's CSS.

- Its 4.7.0 changelog has one entry: `tailwindcss:install` and `tailwindcss:upgrade` now work when the gem sits under a path with spaces. It touches no class, component or attribute, and tailwindcss-ruby stays at 4.3.3.
- It reaches no view, so there is nothing to search `app` for.
- No spec covers the view side of it, since none is affected. `bin/ci` still builds the CSS under the new gem.

## Steps

- Commit the rewritten step 1 of the update order in `.agents/dependencies.md`
- Read the changelogs that can change behaviour: annotaterb 4.26, net-scp 4.2, net-sftp 4.1, rack 3.2.8, rubocop 1.92.1 and 1.92.2 for new cops, and sqlite3 2.10.2
- Name 4.0.9 in `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION`, in their own commit, then run `mise exec -- bundle install`
- Bump cuprite and ferrum in their own commit, with any adaptation they need: `mise exec -- bundle update --conservative cuprite ferrum`
- Bump the remaining gems in one commit: `mise exec -- bundle update --conservative addressable annotaterb bootsnap crass io-console msgpack net-scp net-sftp net-ssh parser rack rubocop sqlite3 tailwindcss-rails`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems moved

## Verification

- `mise exec -- bin/ci` passes under Ruby 4.0.9, browser suite included
- `mise exec -- bin/rspec spec/styleguide` passes, which `bin/ci` never runs
- `grep -qx '4\.0\.9' .ruby-version && grep -q '^ARG RUBY_VERSION=4\.0\.9$' Dockerfile` exits 0, having been seen to exit 1 against 4.0.7
- `mise exec -- gem --version` under Ruby 4.0.9 prints 4.0.23, having been seen to print 4.0.20 before the owner's update
- `grep -A1 '^BUNDLED WITH' Gemfile.lock | grep -q '4\.0\.23'` exits 0, having been seen to exit 1 with a wrong version in the pattern
- `mise exec -- bundle outdated addressable annotaterb bootsnap crass cuprite ferrum io-console msgpack net-scp net-sftp parser rack rubocop sqlite3 tailwindcss-rails` exits 0, having been seen to exit 1 before the bumps
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.8)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 against the `net-ssh` 7.3.6 on `main`
- `grep -q 'mise use -g ruby@<version>' .agents/dependencies.md` exits 0, having been seen to exit 1 against the copy on `main`
- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-01_GHI-390_update-ruby-and-gems.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-11-01_GHI-390_update-ruby-and-gems.md` exits 0

No gate builds the Docker image, so Ruby 4.0.9 and sqlite3 2.10.2's native build go untested there until a deploy runs them, though the `ruby:4.0.9-slim` tag is published. No gate runs the rewritten `mise use -g` line against a Ruby that is not yet installed, since the owner's earlier run had already installed 4.0.9.

## Open questions

None.

## Settled

- **The owner installed Ruby 4.0.9 by hand, made it the global Ruby and ran `gem update --system` under it on 2026-11-01.** That update also brought Bundler to 4.0.23, so `gem install bundler` was not needed.
- **The global Ruby stays on the latest release, the owner's call**, and `mise install` is the fallback where something else on the machine cannot take it.
- **Every upstream hold still stands**, checked on 2026-11-01: rspec-expectations, rspec-mocks and activestorage keep `diff-lcs` and `marcel` below 2.0, kamal 2.12.0 keeps `net-ssh` below 8.0, and rubocop-ast 1.50.0 and ruby-lsp 0.26.11 keep `prism` below 2.0.
