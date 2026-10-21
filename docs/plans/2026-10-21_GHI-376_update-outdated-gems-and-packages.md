> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update outdated gems and packages (#376)

## Approach

The toolchain moves first: Bundler 4.0.23 goes into `Gemfile.lock` with `bundle update --bundler=4.0.23`, which also writes its `bundler (4.0.23)` checksum line, the version named for the trap `.agents/dependencies.md` records. Every Ruby and Node command on this branch runs as `mise exec -- <command>`, so the worktree's `.ruby-version` and `.node-version` decide the versions.

The gems follow with `--conservative`. cuprite 0.19 and ferrum 0.19.1 move in their own commit, since they are 0.x minors that drive the browser suite and cuprite 0.19 requires `ferrum (~> 0.19.1)`. Every other gem in the round is a minor or a patch inside its constraints and moves in one commit: axe-core-api and axe-core-rspec 4.14.0, date 3.6.0, json 3.1.0, net-imap 0.6.8, prettyprint 0.2.1, rack-test 2.3.0, rubocop 1.92.0, rubocop-capybara 3.1.0, sqlite3 2.10.1, uri 1.1.2 and webmock 3.34.0. `diff-lcs`, `marcel`, `net-ssh` and `prism` stay held upstream and are not touched.

`@herb-tools/linter` moves to exactly 0.11.1 with `npm install --save-exact`, and `bin/update-daisyui` moves the vendored daisyUI from 5.7.47 to 5.7.50, each in its own commit.

rubocop 1.92 may enable new cops, since `.rubocop.yml` sets `NewCops: enable`. A new offense is fixed where the cop is right, and stops the round for the owner where it is not, per the linting rules in `CLAUDE.md`.

Dependabot #371, #372 and #373 announce bumps this round takes, and close themselves once `main` carries them.

## Changelog impact

daisyUI is the only package in the round that ships markup or CSS. Every commit from 5.7.48 to 5.7.50 is a forced-colors fix: the indeterminate checkbox mark, and the visibility of `megamenu`, `divider`, `timeline`, `radial-progress`, `rating`, `progress` and `loading`.

- Of those components, the app uses only `checkbox`, in `app/views/members/_form.html.erb`, `app/views/events/_form.html.erb` and `app/views/registrations/new.html.erb`.
- The fix touches only an indeterminate checkbox, and nothing in `app` sets `indeterminate` or `aria-checked="mixed"`, so no view is reached.
- `spec/system/member_edit_page_spec.rb` covers the member form's role checkboxes, `spec/system/event_form_spec.rb` the event form's, and `spec/system/add_someone_spec.rb` the registration form's.

## Steps

- Read the changelogs that can change behaviour: cuprite 0.19, ferrum 0.19.0 and 0.19.1, rubocop 1.92 for new cops, sqlite3 2.10, and webmock 3.27 to 3.34
- Run `bundle update --bundler=4.0.23`, in its own commit
- Bump cuprite and ferrum in their own commit: `bundle update --conservative cuprite ferrum`
- Bump the remaining gems in one commit: `bundle update --conservative axe-core-api axe-core-rspec date json net-imap prettyprint rack-test rubocop rubocop-capybara sqlite3 uri webmock`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems, `BUNDLED WITH` and the `bundler` checksum line moved
- Run `npm install --save-exact @herb-tools/linter@0.11.1`, in its own commit
- Run `bin/update-daisyui` in its own commit, naming 5.7.47 and 5.7.50 in the commit body

## Verification

- `mise exec -- bin/ci` passes, browser suite included
- `mise exec -- bundle outdated axe-core-api axe-core-rspec cuprite date ferrum json net-imap prettyprint rack-test rubocop rubocop-capybara sqlite3 uri webmock` exits 0, having been seen to exit 1 before the bumps
- `grep -A1 '^BUNDLED WITH' Gemfile.lock | grep -q '4\.0\.23' && grep -q 'bundler (4\.0\.23) sha256=' Gemfile.lock` exits 0, having been seen to exit 1 against 4.0.22
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.6)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version substituted into the pattern
- `mise exec -- npm outdated` exits 0, having been seen to exit 1 on `@herb-tools/linter` 0.11.0
- `grep -q '"@herb-tools/linter": "0\.11\.1"' package.json` exits 0, having been seen to exit 1 against 0.11.0
- `grep -q 'var version = "5\.7\.50"' app/assets/tailwind/daisyui.mjs` exits 0, having been seen to exit 1 against the vendored 5.7.47
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-10-21_GHI-376_update-outdated-gems-and-packages.md` exits 0

`npm audit` is already clean, so no gate can be seen red for it; it is read again by hand after the npm commit. No gate builds the Docker image, so sqlite3 2.10.1's native build goes untested until a deploy runs it. No spec runs in forced-colors mode, which is where every daisyUI change in the range lives.

## Open questions

None.

## Settled

- **The owner ran `gem update --system` and `gem install bundler -v 4.0.23` by hand on 2026-10-21.**
- **The `diff-lcs` and `marcel` holds still stand**, checked on 2026-10-21: rspec-expectations 3.13.5 and rspec-mocks 3.13.8 are the latest releases and require `diff-lcs (< 2.0)`, and activestorage 8.1.4 is the latest and requires `marcel (~> 1.0)`.
- **`net-ssh` 8 and `prism` 2 stay out of the round**: kamal, net-scp and net-sftp hold `net-ssh` below 8.0, and rubocop-ast and ruby-lsp hold `prism` below 2.0.
