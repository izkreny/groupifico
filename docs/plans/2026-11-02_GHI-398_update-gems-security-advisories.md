> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update gems with security advisories (#398)

## Approach

The gate moves first. `bin/bundler-audit` takes the `--update` that edge Rails' template carries since rails/rails#55913, which no 8.1 release has, so `bin/ci` refreshes the database on every run. A runner with no database still downloads one, so `scan_ruby` behaves as it did. A refresh with nothing new costs 0.74s and about 2 KB here, and catching up from 2026-08-16 cost 339 KiB.

The local database was last updated on 2026-08-16 and passes the `Gemfile.lock` on `main`, so a refresh has to turn that lockfile red on all three gems. That red is the proof that the local gate now sees what `scan_ruby` sees.

The bumps follow with `--conservative`, in their own commit. All three are transitive patch releases. `Bundler` is already at 4.0.23, so nothing earlier in the update order in `.agents/dependencies.md` moves.

## Changelog impact

Neither `loofah` nor `rails-html-sanitizer` ships markup or CSS of its own, but both decide what survives `simple_format` in `app/views/events/show.html.erb`. The changelogs between the old and new versions are read during implementation, and any entry that changes what a sanitized description renders is named on the pull request. `spec/system/event_detail_spec.rb` covers that view.

## Steps

- Backport `--update` to `bin/bundler-audit` from edge Rails' template
- Record the refreshed audit going red on the `Gemfile.lock` on `main`, naming all three gems
- Read the `loofah`, `nokogiri` and `rails-html-sanitizer` changelogs between the old and new versions
- Bump the gems in one commit: `mise exec -- bundle update --conservative loofah nokogiri rails-html-sanitizer`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems moved

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-02_GHI-398_update-gems-security-advisories.md` exits 0
- A throwaway script gives a bare `bin/bundler-audit` a copy of the database set back to 2026-08-16 and exits 0 when that run moves the copy forward, having been seen to exit 1 against the `bin/bundler-audit` on `main`
- `mise exec -- bin/bundler-audit check` run against the `Gemfile.lock` on `main` exits 1, naming `loofah`, `nokogiri` and `rails-html-sanitizer`
- `mise exec -- bin/bundler-audit` exits 0 after the bumps
- `unshare -rn mise exec -- bin/bundler-audit` exits 1, with the network gone
- `grep -q '^    loofah (2\.25\.3)$' Gemfile.lock && grep -q '^    nokogiri (1\.19\.7)$' Gemfile.lock && grep -q '^    rails-html-sanitizer (1\.7\.2)$' Gemfile.lock` exits 0, having been seen to exit 1 against the `Gemfile.lock` on `main`
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.8)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version in the pattern
- `mise exec -- bin/ci` passes, browser suite included

The throwaway script stays out of the repository, so nothing re-checks the refresh after this branch lands. Offline, `bin/ci` goes red on the gem audit without checking anything, because a failed refresh exits first, and every later step still runs.

## Open questions

None.

## Settled

- **Should the audit backport edge Rails' `--update`, or refresh once a day behind a marker file?** The owner chose the backport, after the measurements showed a refresh costs under a second, so `bin/ci` needs the network on every run.
