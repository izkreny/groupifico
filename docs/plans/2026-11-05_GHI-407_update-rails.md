> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update rails to 8.1.4.1 (#407)

## Approach

The round follows the update order in `.agents/dependencies.md`. Ruby 4.0.9 is already the latest release, so the toolchain step is RubyGems and Bundler 4.0.24, which the owner installs before anything in the repository moves; the branch then names Bundler 4.0.24 in `Gemfile.lock` with `bundle update --bundler=4.0.24`. The gems follow with `--conservative` in two commits: `rails`, which drags its twelve component gems to 8.1.4.1 and nothing else, then `action_policy` and `solid_queue`. None of them is a major release.

## Changelog impact

The 8.1.4.1 release notes change two things this app reaches. Rendered responses now set and extend `Vary` according to the format, which no spec or view here reads. `config.action_dispatch.cookies_same_site_protection` now applies to every session cookie, which meets the signed `session_id` cookie `app/controllers/concerns/authentication.rb` sets with `same_site: :lax`, so a new example in `spec/requests/sign_ins_spec.rb` proves that cookie still leaves the sign-in carrying `SameSite=Lax` and `HttpOnly`.

Nothing in `app`, `lib` or `config` calls `strip_tags`, `highlight`, `safe_constantize` or `ActiveSupport::MessagePack`, and the app has no Active Storage attachments, so the Action View, Active Support and Active Storage fixes change nothing it renders. The `action_policy` 0.7.8 and `solid_queue` 1.7.2 changelogs are read during implementation, and any entry this app reaches is named on the pull request. None of the moving gems ships markup or CSS.

## Steps

- The owner installs RubyGems and Bundler 4.0.24: `mise exec -- gem update --system`, then `mise exec -- gem install bundler -v 4.0.24`
- Name Bundler 4.0.24 in the lockfile: `mise exec -- bundle update --bundler=4.0.24`
- Read the `action_policy` and `solid_queue` changelogs between the old and new versions
- Bump Rails in its own commit: `mise exec -- bundle update --conservative rails`
- Bump the rest in another: `mise exec -- bundle update --conservative action_policy solid_queue`
- Add the sign-in example asserting the session cookie carries `SameSite=Lax` and `HttpOnly`
- Check the `Gemfile.lock` diff against `main` by eye: nothing beyond the named gems, the `BUNDLED WITH` line and the `bundler` checksum line moved

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-05_GHI-407_update-rails.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-05_GHI-407_update-rails.md` exits 0
- `grep -q '^    rails (8\.1\.4\.1)$' Gemfile.lock && grep -q '^    railties (8\.1\.4\.1)$' Gemfile.lock && grep -q '^    action_policy (0\.7\.8)$' Gemfile.lock && grep -q '^    solid_queue (1\.7\.2)$' Gemfile.lock && grep -A1 '^BUNDLED WITH$' Gemfile.lock | grep -qx '  4\.0\.24'` exits 0, having been seen to exit 1 against the `Gemfile.lock` on `main`
- `grep -q '^    diff-lcs (1\.6\.2)$' Gemfile.lock && grep -q '^    marcel (1\.2\.1)$' Gemfile.lock && grep -q '^    net-ssh (7\.3\.8)$' Gemfile.lock && grep -q '^    prism (1\.9\.0)$' Gemfile.lock` exits 0, having been seen to exit 1 with a wrong version in the pattern
- `mise exec -- bin/rspec spec/requests/sign_ins_spec.rb` passes, its new cookie example having been seen red with `same_site: :strict` in `app/controllers/concerns/authentication.rb`
- `mise exec -- bin/bundler-audit` exits 0
- `mise exec -- bin/ci` passes, browser suite included

No gate here reads the `Vary` header a shared cache would see, since no cache sits in front of the app in any environment the suite runs.

## Open questions

None.

## Settled

- **The 8.1.4.1 same-site fix reaches only session stores other than `CookieStore`, never the `session_id` cookie `app/controllers/concerns/authentication.rb` sets with its own `same_site: :lax`, so should the sign-in example stay?** The owner chose to keep it as plain pinning of that cookie's `HttpOnly` and `SameSite=Lax`, which an edit to that line turns red, though this bump cannot.
