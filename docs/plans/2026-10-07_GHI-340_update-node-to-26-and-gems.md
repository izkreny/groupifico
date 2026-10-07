> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update node to 26 and gems (#340)

## Approach

The toolchain moves first, and the repository only has to name what the owner already installed. Node 26 goes into `.node-version`, the one file that names Node: the CI `lint` job's `actions/setup-node` reads it, and the `Dockerfile` installs no Node. Bundler 4.0.22 goes into `Gemfile.lock` with `bundle update --bundler=4.0.22`, which also writes its `bundler (4.0.22)` checksum line, and the version is named for the trap `.agents/dependencies.md` records. Every Ruby and Node command on this branch runs as `mise exec -- <command>`, so the worktree's `.ruby-version` and `.node-version` decide the versions rather than whatever the agent's shell started with.

The gems follow `.agents/dependencies.md`'s order with `--conservative`, all in one commit, since nothing in the round is a major: rails_icons 1.10.0 with the icons 0.11.0 it requires, thruster 0.1.27, net-ssh 7.3.6 and parallel 2.3.0. icons arrives transitively on a 0.x minor, so its changelog is read before the bump, and rails_icons' too, since it syncs the icon files the app renders. `diff-lcs` and `marcel` stay held upstream and are not touched.

`npm audit fix` patches `source-map-js` to 1.2.2 in `package-lock.json`, the one npm change in the round, and `bin/update-daisyui` moves the vendored daisyUI from 5.7.28 to 5.7.47, both per `## Settled`.

Dependabot #333 announces the rails_icons bump and closes itself once `main` carries it.

## Steps

- Read the changelogs that can change behaviour: rails_icons 1.10.0, icons 0.10 and 0.11
- Set `.node-version` to `26` and run `npm ci` under it, in its own commit
- Run `bundle update --bundler=4.0.22`, in its own commit
- Bump the gems in one commit: `bundle update --conservative rails_icons icons thruster net-ssh parallel`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems, `BUNDLED WITH` and the `bundler` checksum line moved
- Run `npm audit fix`, without `--force`, in its own commit: `source-map-js` moves from 1.2.1 to 1.2.2 in `package-lock.json`, and `package.json` stays as it is
- Read daisyUI's changelog from 5.7.29 to 5.7.47, then run `bin/update-daisyui` in its own commit, naming both versions in the commit body

## Verification

- `mise exec -- bin/ci` passes, browser suite included
- `mise exec -- node --version | grep -q '^v26\.'` exits 0, having been seen to exit 1 before the `.node-version` edit
- `gh run view --job <lint-job-id> --log | grep -q 'node: v26\.'` exits 0 on this branch's latest CI run, having been seen to exit 1 against `main`'s lint job 110424183755
- `mise exec -- bundle outdated rails_icons icons thruster net-ssh parallel` exits 0, having been seen to exit 1 before the bumps
- `grep -A1 '^BUNDLED WITH' Gemfile.lock | grep -q '4\.0\.22' && grep -q 'bundler (4\.0\.22) sha256=' Gemfile.lock` exits 0, having been seen to exit 1 against 4.0.21
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version substituted into the pattern
- `mise exec -- npm audit` exits 0, having been seen to exit 1 on GHSA-68fv-2mgg-jv7q before the fix
- `git diff --exit-code origin/main -- package.json` exits 0, having been seen to exit 1 with a scratch edit to `package.json`
- `grep -q 'var version = "5\.7\.47"' app/assets/tailwind/daisyui.mjs` exits 0, having been seen to exit 1 against the vendored 5.7.28
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-10-07_GHI-340_update-node-to-26-and-gems.md` exits 0

No gate here builds the Docker image, so thruster 0.1.27 goes untested until a deploy runs it under Puma. Node 26 runs only `herb-lint`, so the gates cover everything it does here. Dependabot's self-close happens on `main` after the merge, and gets checked there.

## Open questions

None.

## Settled

- **Node 26 lands before it turns LTS on 2026-10-28**, which the owner chose on 2026-10-07, since all Node does here is run the Herb linter.
- **The owner ran `gem update --system` and `gem install bundler -v 4.0.22` by hand on 2026-10-07**, and Node 26 is already installed on the owner's machine.
- **The `source-map-js` advisory folds into this branch**, which the owner decided on 2026-10-07 once `npm audit` showed GHSA-68fv-2mgg-jv7q (high) on 1.2.1, reached through `@herb-tools/linter` and `postcss`. `npm audit fix` without `--force` stays inside the declared ranges, so it moves that one lockfile entry to 1.2.2 and nothing else.
- **daisyUI 5.7.47 folds into this branch too**, which the owner decided on 2026-10-07: an update round covers every upgradable package in one issue. daisyUI is vendored, so `bin/update-daisyui` moves it until #273 delivers it from npm. Every release from 5.7.29 to 5.7.47 is a bug fix; the ones that reach this app's markup are the active styling for `aria-current` in `menu` and `dock`, which the group switcher already pairs with `menu-active` and the browser suite checks for contrast on the dock.
