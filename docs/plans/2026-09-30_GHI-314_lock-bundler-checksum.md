> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: lock bundler's own checksum (#314)

## Approach

Bundler writes a `CHECKSUMS` entry for itself only when `bundler-<version>.gem` sits in the gem cache: `Bundler::LockfileGenerator#bundler_checksum` hashes that cached file, and without it keeps whatever entry is already locked, or drops it when `BUNDLED WITH` is changing. So no single command writes the line: `bundle install` and `bundle update --bundler=<version>` both append it on a machine that holds the cached gem, and neither writes it where Bundler arrived as RubyGems' default gem through `gem update --system`, which caches no `.gem`. Measured on this branch: with the lockfile as on `main` and `bundler-4.0.21.gem` made visible as the cached file, both commands append exactly the line the issue quotes, and with the line already locked `bundle check`, `bundle install`, `bundle lock`, `bundle update --bundler=4.0.21`, `bundle update --conservative` and a frozen `bundle install` all leave the lockfile byte-identical, and `bundle install` and `bundle update --bundler=4.0.21` still do with the cached gem visible.

The fix is therefore the line itself, in a `build` commit on its own, since once locked every machine keeps it. Its checksum comes from `gem fetch bundler -v 4.0.21` and `sha256sum`, cross-checked against the `sha` rubygems.org publishes for that version; all three agree on `7cbf5499…1f1dd0`. Bundler sorts the entry above `bundler-audit`, and a line placed below it is moved on the next write, so it goes in sort order.

`.agents/dependencies.md` then gains that account under step 2 of *The update order*: which command writes the line and when, that a default-gem Bundler leaves step 2 without one, how to write it by the same fetch-and-verify route, and that the lockfile diff check expects `bundler (<version>) sha256=…` beside the `BUNDLED WITH` line.

## Steps

- Fetch `bundler-4.0.21.gem` outside the working tree, and confirm its `sha256sum` matches rubygems.org's published `sha` and the issue's line
- Add `bundler (4.0.21) sha256=7cbf5499b426076aa16c8d28a59e4c2c3aad5a438402abcd961f0119f29f1dd0` to `Gemfile.lock`'s `CHECKSUMS`, above `bundler-audit`, and commit it alone as `build`
- Extend step 2 of *The update order* and the lockfile diff check in `.agents/dependencies.md`, and commit it as `docs`
- Run `bin/ci` in this worktree, which was created fresh for the issue, and read `git status` after it

## Verification

- `grep -qx '  bundler (4.0.21) sha256=7cbf5499b426076aa16c8d28a59e4c2c3aad5a438402abcd961f0119f29f1dd0' Gemfile.lock` exits 0, having been seen to exit 1 on `main`
- With `bundler-4.0.21.gem` fetched to a temporary directory and a `RUBYOPT`-required file overriding `Gem::Specification#cache_file` for bundler 4.0.21 to point at it, `bundle install && git diff --exit-code Gemfile.lock` exits 0, having been seen to exit 1 against `main`'s lockfile
- `bin/ci` is green, or red only at *Tests: System*, and `git status --porcelain` prints nothing after it
- Every failing system example is axe's `color-contrast` on `.validator-hint`: `bin/rspec spec/system --format json --out tmp/system.json` followed by a `ruby -rjson` check that each failed example's exception message names both, seen to fail on a JSON carrying one other failure
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-09-30_GHI-314_lock-bundler-checksum.md .agents/dependencies.md` exits 0

On this machine `bin/setup` already leaves the tree clean without the fix, because Bundler 4.0.21 is the default gem and nothing is cached, so the `bin/ci` gate cannot fail here on the defect; the cached-gem gate is the one that reproduces it. The system-spec exception is the light-theme `.validator-hint` contrast failure that is red on `main` too, until #257 and #299 land.

## Open questions

- Should step 1 of the update order also have the owner run `gem install bundler -v <version>`, so the gem is cached and step 2 writes the line itself? It cannot be verified here without an install, so the doc assumes the fetch-and-verify route instead.

## Settled

None yet.
