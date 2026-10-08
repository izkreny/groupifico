> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: document the full update round (#342)

## Approach

`.agents/dependencies.md` gains what an update round is, ahead of how a gem moves. A new `## An update round` section opens the file: one update issue covers every upgradable package and a round is never split per ecosystem, every Ruby and Node command in it runs as `mise exec -- <command>`, and the round starts by taking the inventory. The inventory follows as a list rather than a table, since several of its commands carry a `|`: each entry names what is read and the command that reads it, every one of which was run on this branch before the plan was written.

`## The update order` stays the backbone. Ruby joins the head of it, before RubyGems and Bundler, because it is toolchain like them and the gems are built against it; moving it means `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION` together, after the owner installs it. The ecosystems the order does not cover yet slot in after the gems, each in its own commit: Node through `.node-version` and `npm ci`, the npm packages with `npm audit fix` and never `--force`, the vendored daisyUI through `bin/update-daisyui` until #273 replaces that step with the npm route, and the GitHub Actions majors.

The importmap pins are served from `turbo-rails` and `stimulus-rails`, so they move when those gems do and the inventory says so; `bin/importmap outdated` is named only as the confirmation that nothing is pinned from npm, never as the check that would catch a stale Turbo.

A `## The changelog impact check` section makes it a requirement of the round's plan, for every package that ships markup or CSS: the changelog entries that touch a class or attribute the app uses, the views a search for each one finds, and the specs that cover those views. The `AGENTS.md` pointer names the round, the inventory and the impact check alongside what it lists today.

## Steps

- Rewrite the opening of `.agents/dependencies.md` and its "read this before" line so they cover an update round, not only a gem
- Add `## An update round`: one issue for every upgradable package, never split per ecosystem, the `mise exec --` rule, and the inventory with the command for each entry
- Extend `## The update order`: Ruby at its head, then Node, the npm packages with `npm audit fix` without `--force`, daisyUI through `bin/update-daisyui` until #273, and the Actions majors after the gems
- Add `## The changelog impact check` as a requirement on the round's plan
- Update the `.agents/dependencies.md` pointer in `AGENTS.md` to name the new contents

## Verification

- `grep -q 'mise exec --' .agents/dependencies.md` exits 0, having been seen to exit 1 on `main`
- `grep -q 'npm audit fix' .agents/dependencies.md` exits 0, having been seen to exit 1 on `main`
- `grep -q 'bin/update-daisyui' .agents/dependencies.md` exits 0, having been seen to exit 1 on `main`
- `grep -q 'changelog impact check' .agents/dependencies.md` exits 0, having been seen to exit 1 on `main`
- `grep -q 'inventory' AGENTS.md` exits 0, having been seen to exit 1 on `main`
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' AGENTS.md .agents/dependencies.md docs/plans/2026-10-07_GHI-342_full-update-round.md` exits 0
- `mise exec -- bin/ci` passes

The greps prove that each required topic landed, not that a listed command answers what the file says it answers; that is a reading, and the review round judges it against the commands as written.

## Open questions

None.

## Settled

None yet.
