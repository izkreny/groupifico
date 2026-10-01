> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: bump brakeman to 8.1.0 (#317)

## Approach

`bin/brakeman` prepends `--ensure-latest`, so the lock holding 8.0.6 while 8.1.0 is published makes it exit 5 before scanning anything; reproduced in this worktree on `main`'s tree. The fix is step 3 of *The update order* in `.agents/dependencies.md`, `bundle update --conservative brakeman`, with no toolchain step before it since the branch moves no Bundler. 8.1.0 declares the same single runtime dependency as 8.0.6, `racc (>= 0)`, so the lockfile diff should touch only the `brakeman` spec line and its `CHECKSUMS` line.

Brakeman 8.1.0's changelog is read before the bump, for new or changed checks that could report against existing code. A warning 8.1.0 raises is resolved in the code it names if the fix is in scope, and otherwise raised on the issue rather than suppressed, since `--exit-on-warn` makes any warning a red `scan_ruby`.

## Steps

- Read Brakeman's 8.1.0 changelog and note any check that is new or tightened
- Run `bundle update --conservative brakeman`, check the `Gemfile.lock` diff by eye against `main`'s copy, and commit it alone as `build`
- Run `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`; on a new warning, stop and raise it on the issue unless the fix is a small in-scope code change
- Run `bin/ci` in this worktree

## Verification

- `git diff main -- Gemfile.lock` changes exactly the `brakeman (8.0.6)` spec line and its `CHECKSUMS` line, to 8.1.0
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` exits 0, having been seen to exit 5 on `main`'s lockfile
- The pull request's `scan_ruby` check passes
- `bin/ci` is green, or red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-01_GHI-317_bump-brakeman.md` exits 0

The `--ensure-latest` gate goes red again whenever Brakeman next releases, which no gate here can prevent; whether to keep that flag is a separate decision this issue does not take.

## Open questions

None.

## Settled

None yet.
