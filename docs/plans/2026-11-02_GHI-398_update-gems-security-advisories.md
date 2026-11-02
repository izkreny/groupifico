> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update gems with security advisories (#398)

## Approach

The gate moves first. `config/ci.rb` adds a `Security: Refresh gem advisories` step ahead of the gem audit unless the `.advisory_database_checked_at` marker holds today's date, so the database is checked at least once a day. The step runs `bin/bundler-audit update` and writes the date only when that succeeds, and `update` also downloads a missing database. The marker sits in the database's own folder, because every worktree shares that database, so one refresh covers all of them and a deleted database takes its marker with it. The `Security: Gem audit` step itself does not change.

The local database was last updated on 2026-08-16 and passes the `Gemfile.lock` on `main`, so a refresh has to turn that lockfile red on all three gems. That red is the proof that the local gate now sees what `scan_ruby` sees.

The bumps follow with `--conservative`, in their own commit. All three are transitive patch releases. `Bundler` is already at 4.0.23, so nothing earlier in the update order in `.agents/dependencies.md` moves.

## Changelog impact

Neither `loofah` nor `rails-html-sanitizer` ships markup or CSS of its own, but both decide what survives `simple_format` in `app/views/events/show.html.erb`. The changelogs between the old and new versions are read during implementation, and any entry that changes what a sanitized description renders is named on the pull request. `spec/system/event_detail_spec.rb` covers that view.

## Steps

- Make `bin/ci` refresh the advisory database once a day, recording the day in a marker
- Record the refreshed audit going red on the `Gemfile.lock` on `main`, naming all three gems
- Read the `loofah`, `nokogiri` and `rails-html-sanitizer` changelogs between the old and new versions
- Bump the gems in one commit: `mise exec -- bundle update --conservative loofah nokogiri rails-html-sanitizer`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems moved

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- A throwaway script stubs `CI`, loads `config/ci.rb` and exits 0 when the refresh step appears with no marker, with yesterday's marker and with no database, is absent with today's marker, writes no marker when the refresh fails offline and writes today's date when it succeeds, having been seen to exit 1 against the copy of `config/ci.rb` on `main`
- `mise exec -- bin/bundler-audit check` run against the `Gemfile.lock` on `main` exits 1 on the refreshed database, naming `loofah`, `nokogiri` and `rails-html-sanitizer`
- `mise exec -- bin/bundler-audit check` exits 0 after the bumps, on the refreshed database
- `unshare -rn mise exec -- bin/bundler-audit check` exits 0 after the bumps, with the network gone
- `unshare -rn mise exec -- bin/bundler-audit update` exits 1, with the network gone
- `grep -q '^    loofah (2\.25\.3)$' Gemfile.lock && grep -q '^    nokogiri (1\.19\.7)$' Gemfile.lock && grep -q '^    rails-html-sanitizer (1\.7\.2)$' Gemfile.lock` exits 0, having been seen to exit 1 against the `Gemfile.lock` on `main`
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.8)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version in the pattern
- `mise exec -- bin/ci` passes, browser suite included

The throwaway script stays out of the repository, so nothing re-checks the daily condition after this branch lands. No gate runs `bin/ci` end to end without a network. Offline, the day's first `bin/ci` goes red on the refresh step and every later step still runs, and that repeats until a refresh succeeds.

## Open questions

None.

## Settled

- **The owner chose the refresh condition**: the database is checked at least once a day, and a `.advisory_database_checked_at` file records the day it was last checked, so later runs that day need no network.
