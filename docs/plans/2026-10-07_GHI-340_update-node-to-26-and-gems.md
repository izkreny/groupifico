> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update node to 26 and gems (#340)

## Approach

The toolchain moves first, and the repository only has to name what the owner already installed. Node 26 goes into `.node-version`, the one file that names Node: the CI `lint` job's `actions/setup-node` reads it, and the `Dockerfile` installs no Node. Bundler 4.0.22 goes into `Gemfile.lock` with `bundle update --bundler=4.0.22`, which also writes its `bundler (4.0.22)` checksum line, and the version is named for the trap `.agents/dependencies.md` records. Every Ruby and Node command on this branch runs as `mise exec -- <command>`, so the worktree's `.ruby-version` and `.node-version` decide the versions rather than whatever the agent's shell started with.

The gems follow `.agents/dependencies.md`'s order with `--conservative`, all in one commit, since nothing in the round is a major: rails_icons 1.10.0 with the icons 0.11.0 it requires, thruster 0.1.27, net-ssh 7.3.6 and parallel 2.3.0. icons arrives transitively on a 0.x minor, so its changelog is read before the bump, and rails_icons' too, since it syncs the icon files the app renders. `diff-lcs` and `marcel` stay held upstream and are not touched.

Dependabot #333 announces the rails_icons bump and closes itself once `main` carries it.

## Steps

- Read the changelogs that can change behaviour: rails_icons 1.10.0, icons 0.10 and 0.11
- Set `.node-version` to `26` and run `npm ci` under it, in its own commit
- Run `bundle update --bundler=4.0.22`, in its own commit
- Bump the gems in one commit: `bundle update --conservative rails_icons icons thruster net-ssh parallel`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems, `BUNDLED WITH` and the `bundler` checksum line moved

## Verification

- `mise exec -- bin/ci` passes, browser suite included
- `mise exec -- node --version | grep -q '^v26\.'` exits 0, having been seen to exit 1 before the `.node-version` edit
- `gh run view --job <lint-job-id> --log | grep -q 'node: v26\.'` exits 0 on this branch's latest CI run, having been seen to exit 1 against `main`'s lint job 110424183755
- `mise exec -- bundle outdated rails_icons icons thruster net-ssh parallel` exits 0, having been seen to exit 1 before the bumps
- `grep -A1 '^BUNDLED WITH' Gemfile.lock | grep -q '4\.0\.22' && grep -q 'bundler (4\.0\.22) sha256=' Gemfile.lock` exits 0, having been seen to exit 1 against 4.0.21
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version substituted into the pattern
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-10-07_GHI-340_update-node-to-26-and-gems.md` exits 0

No gate here builds the Docker image, so thruster 0.1.27 goes untested until a deploy runs it under Puma. Node 26 runs only `herb-lint`, so the gates cover everything it does here. Dependabot's self-close happens on `main` after the merge, and gets checked there.

## Open questions

None.

## Settled

- **Node 26 lands before it turns LTS on 2026-10-28**, which the owner chose on 2026-10-07, since all Node does here is run the Herb linter.
- **The owner ran `gem update --system` and `gem install bundler -v 4.0.22` by hand on 2026-10-07**, and Node 26 is already installed on the owner's machine.
