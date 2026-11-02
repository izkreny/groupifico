> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update gems with security advisories (#398)

## Approach

The gate moves first. The `Security: Gem audit` step in `config/ci.rb` reads `last_updated_at` from `Bundler::Audit::Database` and adds `--update` when that date is older than 7 days. A machine with no database takes the plain `check`, which downloads one. The date is the newest upstream commit in the database, so a quiet week upstream costs a refresh on every run until something lands there, which is cheap and needs the network only for those runs.

The local database was last updated on 2026-08-16 and passes the current lockfile, so the first run of the new step refreshes it and has to go red on all three gems. That red is the proof that the local gate now sees what `scan_ruby` sees, and it has to be recorded before the bumps remove it.

The bumps follow with `--conservative`, in their own commit. All three are transitive patch releases. `Bundler` is already at 4.0.23, so nothing earlier in the update order in `.agents/dependencies.md` moves.

## Changelog impact

Neither `loofah` nor `rails-html-sanitizer` ships markup or CSS of its own, but both decide what survives `simple_format` in `app/views/events/show.html.erb`. The changelogs between the old and new versions are read during implementation, and any entry that changes what a sanitized description renders is named on the pull request. `spec/system/event_detail_spec.rb` covers that view.

## Steps

- Make the gem audit step refresh a database older than 7 days, in its own commit
- Record the step going red on the current lockfile, naming all three gems
- Read the `loofah`, `nokogiri` and `rails-html-sanitizer` changelogs between the old and new versions
- Bump the gems in one commit: `mise exec -- bundle update --conservative loofah nokogiri rails-html-sanitizer`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems moved

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- A throwaway script stubs `CI`, loads `config/ci.rb` and exits 0 when the gem audit step carries `--update` for a database 8 days old and leaves it off for one 6 days old and for a missing one, having been seen to exit 1 against the copy of `config/ci.rb` on `main`
- `mise exec -- bin/bundler-audit check --update` exits 1 on the current lockfile, naming `loofah`, `nokogiri` and `rails-html-sanitizer`
- `mise exec -- bin/bundler-audit check` exits 0 after the bumps, on the refreshed database
- `unshare -rn mise exec -- bin/bundler-audit check` exits 0 after the bumps, with the network gone
- `unshare -rn mise exec -- bin/bundler-audit check --update` exits 1, with the network gone
- `grep -q '^    loofah (2\.25\.3)$' Gemfile.lock && grep -q '^    nokogiri (1\.19\.7)$' Gemfile.lock && grep -q '^    rails-html-sanitizer (1\.7\.2)$' Gemfile.lock` exits 0, having been seen to exit 1 against the `Gemfile.lock` on `main`
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.8)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version in the pattern
- `mise exec -- bin/ci` passes, browser suite included

The throwaway script stays out of the repository, so nothing re-checks the 7-day condition after this branch lands. No gate runs `bin/ci` end to end without a network, so "works offline" rests on each network-touching step having been run offline on this machine, with npm's cache warm.

## Open questions

None.

## Settled

- **The owner chose the refresh condition**: `--update` only when the advisory database is older than 7 days, so `bin/ci` keeps working offline between refreshes. Asked at the start of this round, because nothing else in `bin/ci` reaches the network today.
