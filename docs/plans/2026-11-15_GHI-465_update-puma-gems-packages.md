> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update puma, gems and packages (#465)

## Approach

The round follows the update order in `.agents/dependencies.md`. Ruby 4.0.9, RubyGems and Bundler 4.0.24 are already current, so the toolchain steps are skipped and `BUNDLED WITH` stays. The gems move with `--conservative` in three commits: `puma` alone first, so the security fix stays revertable on its own; then `rspec-rails` with its `Gemfile` pin and the `rspec-*` gems it locks; then the rest. `@herb-tools/linter` and the vendored daisyUI follow, each in its own commit. Nothing moving is a major release.

`puma` 8.1.0 and 8.1.1 were both released today, 2026-11-15. The issue names 8.1.1, the latest. 8.0.3, released 2026-11-13, is the fallback that still clears all seven advisories if 8.1 turns out wrong.

## Changelog impact

**`puma`.** No entry names an option `config/puma.rb` sets: `threads`, `port`, `plugin :tmp_restart`, `plugin :solid_queue` and `pidfile`. The app runs in single mode, so the cluster entries (`mold_worker`, refork, the worker hooks) do not apply. It does inherit three new defaults:
- 8.0.3's `shutdown_body_timeout` of 25 seconds bounds how long a restart waits on an incomplete request body. That sits inside Kamal 2.12.0's default `drain_timeout` of 30 seconds (`Kamal::Configuration#drain_timeout`).
- 8.1.0 answers 400 to an HTTP/1.1 request with no `Host` header, or an empty one.
- 8.1.0 parses request paths, underscore headers and chunk sizes more strictly.

**`rspec-rails`.** 8.1.0 states that it changes no Rails 8.1 behaviour from 8.0.x. 8.0.5 includes `ActiveJob::TestHelper` in every Rails example group and fixes `have_enqueued_mail` argument matching. Those reach `spec/models/event_spec.rb`, `spec/models/registration_spec.rb`, `spec/models/member/import_spec.rb`, and the explicit include in `spec/jobs/feedback/file_issue_job_spec.rb`, all run by `bin/ci`. No spec here is a view spec or sets `default_url_options`.

**daisyUI 5.8.0** ships CSS. The entries that reach a component the app uses, with the views and the specs that cover them:
- **alert**, a layout for a missing icon, plus the reduced-motion guards:
  - Views: `app/views/shared/_alert.html.erb`, `app/views/layouts/_flash.html.erb`, `app/views/feedbacks/new.html.erb`. The app's alert always carries an icon.
  - Specs: `spec/system/feedback_spec.rb`, `spec/requests/feedbacks_spec.rb`, `spec/styleguide/styleguide_spec.rb`. `shared/_alert` has no spec of its own.
- **join**, the radius taken from the main element, the end border of a disabled last item, and the focus z-index:
  - Code: `app/form_builders/app_form_builder.rb`, used by `app/views/events/_form.html.erb`.
  - Specs: `spec/form_builders/app_form_builder_spec.rb`, `spec/requests/events_spec.rb`.
- **menu**, paged transitions and reduced motion:
  - Views: `app/views/events/_scope_menu.html.erb`, `app/views/layouts/_group_switcher.html.erb`, `app/views/layouts/_me_menu.html.erb`, `app/views/user_profiles/edit.html.erb`.
  - Specs: `spec/system/group_shell_spec.rb`, `spec/system/me_spec.rb`, `spec/styleguide/styleguide_spec.rb`. `_scope_menu` is reached only by request specs, which run no browser.
- **tab**, any `aria-current` other than `false` or empty now styled as active:
  - Views: `app/views/layouts/_header.html.erb`, `app/views/layouts/_group_tabs.html.erb`, `app/views/members/index.html.erb`.
  - Specs: `spec/system/group_shell_spec.rb`, `spec/system/members_list_spec.rb`.
- **Forced-colours fixes only** on `btn-disabled`, collapse, modal, select, radio, toggle, status and avatar. They change nothing outside Windows high-contrast mode.
- Components the app does not use, among them range, megamenu, fab, footer, timeline, otp, progress and steps.
- `app/assets/tailwind/application.css` loads the plugin with no `include` or `exclude`, so the option-matching fix does not apply.

**`tailwindcss-ruby` 4.3.4** bundles Tailwind CSS 4.3.4 in place of 4.3.3. Its compiler fixes reach candidate extraction and source detection, including detection that respects `!` negations in `.gitignore`, which this repository's `.gitignore` carries. No view or helper uses an affected candidate shape (a `/` modifier on `rounded`, `shadow` or `stroke`, or an empty modifier). The compiled-CSS diff in S5 is what shows whether the output moved at all.

**`@herb-tools/linter` 0.11.2** adds the `erb-no-trailing-comment` rule. `.herb.yml`'s `version:` stays at 0.11.1, which leaves that rule off; turning it on is not this round's scope. The parser changes are not locked by that key, so V7 runs the linter over every view.

`cuprite` 0.20.1 fixes `scroll_to`, which no spec calls. `minitest` 6.1.0 and `irb` 1.19.0 change nothing this app calls.

## Steps

- ::S1:: Bump `puma` in its own commit: `mise exec -- bundle update --conservative puma`
- ::S2:: Move the `rspec-rails` pin in `Gemfile` to `~> 8.1.0`, the README's one-minor style, then `mise exec -- bundle update --conservative rspec-rails rspec-core rspec-expectations rspec-mocks rspec-support`, in one commit
- ::S3:: Bump the rest in another commit: `mise exec -- bundle update --conservative cuprite hashdiff irb minitest net-scp rubocop-ast tailwindcss-ruby`
- ::S4:: Bump the linter: `mise exec -- npm install --save-exact @herb-tools/linter@0.11.2`, then `mise exec -- npm audit fix`, in one commit
- ::S5:: Build the compiled stylesheet with `mise exec -- bin/rails tailwindcss:build` at three points: on `main`, after S3, and after S6. Post the diff of each step on the pull request, so the Tailwind 4.3.4 move and the daisyUI move each show how broad they are
- ::S6:: Bump daisyUI with `bin/update-daisyui`, stopping if `app/assets/tailwind/daisyui.mjs` then names anything but 5.8.0. Commit it with 5.7.50 → 5.8.0 named in the body
- ::S7:: Check the `Gemfile.lock` diff against `main` by eye: only the named gems moved, each `tailwindcss-ruby` platform line with them
- ::S8:: If `--conservative` refuses a gem or drags one in that is not named, update the issue's AC4 and AC7 to match and name the change on the pull request

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-15_GHI-465_update-puma-gems-packages.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-15_GHI-465_update-puma-gems-packages.md` exits 0
- ::V3:: `for g in 'puma (8\.1\.1)' 'rspec-rails (8\.1\.0)' 'cuprite (0\.20\.1)' 'hashdiff (1\.2\.2)' 'irb (1\.19\.0)' 'minitest (6\.1\.0)' 'net-scp (4\.2\.2)' 'rspec-core (3\.13\.7)' 'rspec-expectations (3\.13\.6)' 'rspec-mocks (3\.13\.9)' 'rspec-support (3\.13\.8)' 'rubocop-ast (1\.51\.0)' 'tailwindcss-ruby (4\.3\.4)'; do grep -q "^    $g\$" Gemfile.lock || exit 1; done && grep -q '^  gem "rspec-rails", "~> 8\.1\.0"$' Gemfile` exits 0; seen to exit 1 against `main`'s `Gemfile.lock` and `Gemfile`
- ::V4:: `for g in 'diff-lcs (1\.6\.2)' 'marcel (1\.2\.1)' 'net-ssh (7\.3\.8)' 'prism (1\.9\.0)'; do grep -q "^    $g\$" Gemfile.lock || exit 1; done` exits 0; seen to exit 1 with `diff-lcs (1\.6\.3)` in the pattern
- ::V5:: `grep -q '"@herb-tools/linter": "0\.11\.2"' package.json && grep -q 'var version = "5\.8\.0"' app/assets/tailwind/daisyui.mjs` exits 0; seen to exit 1 against `main`
- ::V6:: `mise exec -- bin/bundler-audit` exits 0, seen to exit 1 against `main`, and `mise exec -- npm audit` exits 0
- ::V7:: `node_modules/.bin/herb-lint --ignore-disable-comments` over every view exits 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

No gate here boots `puma` behind kamal-proxy. That leaves the new `Host` 400 and the shutdown body timeout proven only by the changelog and Kamal's default, until the first deploy. Whether daisyUI 5.8.0's and Tailwind 4.3.4's CSS changes read well on screen is the owner's judgement, informed by S5's diffs.

## Open questions

None.

## Settled

None yet.
