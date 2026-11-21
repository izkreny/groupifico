> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update ruby, brakeman, gems and daisyui (#499)

## Approach

The round follows *The update order* in `.agents/dependencies.md`, and every Ruby command on this branch runs as `mise exec -- <command>`. The toolchain moves first. Once the owner has installed Ruby 4.0.10 and, under it, RubyGems 4.1.0 and Bundler 4.1.0 (N3), `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION` name 4.0.10 in one commit, followed by `mise exec -- bundle install`. The `ruby:4.0.10-slim` image tag is published. `mise exec -- bundle update --bundler=4.1.0` then writes `BUNDLED WITH` and the `bundler (4.1.0)` checksum line in a commit of its own, with the version named because of *The `BUNDLED WITH` trap*.

Brakeman 8.1.1 moves next, in its own commit, because it is what turns `scan_ruby` green, and `bin/brakeman` runs with `--ensure-latest`. The remaining patch bumps go in one commit with `--conservative`: `bootsnap`, `ferrum`, `puma`, `rubocop`, `thruster` and `webmock`, with the transitive `connection_pool`, `parser`, `rack`, `regexp_parser` and `rubocop-ast` named alongside, so nothing else moves. rubocop 1.92.3 and rubocop-ast 1.53.0 can raise new offenses under `NewCops: enable`, and Brakeman 8.1.1 can raise new warnings. Either one stops the round for the owner rather than being suppressed or worked around, per the linting rules in `CLAUDE.md`.

## AC5, gem by gem

- `prism` 2.1.0 is left. `ruby-lsp` 0.26.11, its latest release, requires `prism (>= 1.2, < 2.0)`.
- `net-ssh` 8.1.2 is left. `kamal` 2.12.0, its latest release, requires `net-ssh (~> 7.3)`.
- `websocket-extensions` 0.2.0 moves in a commit of its own, ahead of the driver. Its changelog adds an `options` argument to `WebSocket::Extensions.new` and spec-compliant whitespace in the header parser, and `websocket-driver` 0.8.2 already admits it (`>= 0.1.0`).
- `websocket-driver` 0.9.0 moves in the commit after it. It requires `websocket-extensions (>= 0.2.0)` and `base64`, which is already locked. Its changelog turns off the `draft75` and `draft76` protocols by default and fixes bugs in their parsers. `ferrum` speaks RFC 6455 to Chrome, as does every browser that opens an Action Cable socket, so neither consumer uses a draft protocol, and `ferrum`'s `~> 0.7` admits 0.9.0. The browser suite exercises `ferrum`'s client. Nothing exercises Action Cable's server side: `app/channels/application_cable/connection.rb` exists, but no view subscribes to a stream.

`prism` and `net-ssh` therefore join N1's `diff-lcs` and `marcel` as deliberately left, and AC7's "the gems this issue names" has to cover them. The issue's N1 gets the two of them with their holds, read, modify, write, so the issue names every gem that `bundle outdated` will still list.

## Changelog impact

daisyUI is the only package in the round that ships CSS. Its changelog between 5.8.0 and 5.8.2 has two entries:

- 5.8.1: the megamenu's hover indicator under RTL. `grep -rn 'megamenu' app --include=*.erb --include=*.rb --include=*.css` finds nothing, and no layout sets `dir=`, so it reaches no view.
- 5.8.2: the `avatar-online` and `avatar-offline` dots print instead of being dropped. `grep -rnE 'avatar-online|avatar-offline' app --include=*.erb --include=*.rb --include=*.css` finds nothing, so it reaches no view. The app's avatars, in `app/views/layouts/_header.html.erb`, `app/views/layouts/_me_menu.html.erb`, `app/views/members/_member.html.erb`, `app/views/members/show.html.erb`, `app/views/user_profiles/edit.html.erb` and `app/views/user_profiles/_user_profile.html.erb`, carry neither status class.
- With no view reached, no spec covers a change. `spec/system/group_shell_spec.rb`, `spec/system/me_spec.rb` and `spec/system/groups_index_spec.rb` still render those avatars under the new CSS in `bin/ci`.

## Steps

- ::S1:: Confirm the owner's installs: `mise exec ruby@4.0.10 -- ruby -e 'exit(Gem::VERSION == "4.1.0")'` exits 0 and `mise exec ruby@4.0.10 -- gem list --exact bundler` lists 4.1.0. Stop and name what is missing otherwise
- ::S2:: Name 4.0.10 in `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION`, then run `mise exec -- bundle install`, in one commit
- ::S3:: `mise exec -- bundle update --bundler=4.1.0`, in its own commit
- ::S4:: `mise exec -- bundle update --conservative brakeman`, in its own commit, then `mise exec -- bin/brakeman --no-pager`
- ::S5:: `mise exec -- bundle update --conservative bootsnap ferrum puma rubocop thruster webmock connection_pool parser rack regexp_parser rubocop-ast`, in one commit, after reading the rubocop 1.92.3 changelog for new cops
- ::S6:: `mise exec -- bundle update --conservative websocket-extensions` in one commit, then `mise exec -- bundle update --conservative websocket-driver` in the next
- ::S7:: Run `bin/update-daisyui`, stopping if `app/assets/tailwind/daisyui.mjs` then names anything but 5.8.2, and commit it with 5.8.0 → 5.8.2 named in the body
- ::S8:: Add `prism` and `net-ssh` with their holds to N1 on #499, read, modify, write
- ::S9:: Check the `Gemfile.lock` diff against `main` by eye: only the named gems moved, each `thruster` platform line with them, plus the `BUNDLED WITH` and `bundler (4.1.0)` checksum lines
- ::S10:: If `--conservative` refuses a gem or drags in one that is not named, update the issue's AC4 and AC7 to match and name the change on the pull request

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-499_update-ruby-brakeman-gems-daisyui.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-499_update-ruby-brakeman-gems-daisyui.md` exits 0
- ::V3:: `grep -qx '4\.0\.10' .ruby-version && grep -q '^ARG RUBY_VERSION=4\.0\.10$' Dockerfile && mise exec -- ruby -e 'exit(RUBY_VERSION == "4.0.10" && Gem::VERSION == "4.1.0")'` exits 0; seen to exit 1 against `main` (AC1)
- ::V4:: `grep -A1 '^BUNDLED WITH' Gemfile.lock | grep -qx '  4\.1\.0' && grep -q '^  bundler (4\.1\.0) sha256=' Gemfile.lock` exits 0; seen to exit 1 against `main` (AC2)
- ::V5:: `mise exec -- bin/brakeman --no-pager` exits 0; seen to exit non-zero on `main`'s Brakeman 8.1.0 under `--ensure-latest` (AC3)
- ::V6:: `for g in 'brakeman (8\.1\.1)' 'bootsnap (1\.26\.2)' 'ferrum (0\.20\.2)' 'puma (8\.1\.2)' 'rubocop (1\.92\.3)' 'thruster (0\.1\.28)' 'webmock (3\.36\.0)' 'connection_pool (3\.0\.3)' 'parser (3\.3\.14\.0)' 'rack (3\.2\.9)' 'regexp_parser (2\.13\.4)' 'rubocop-ast (1\.53\.0)' 'websocket-driver (0\.9\.0)' 'websocket-extensions (0\.2\.0)' 'prism (1\.9\.0)' 'net-ssh (7\.3\.8)' 'diff-lcs (1\.6\.2)' 'marcel (1\.2\.1)'; do grep -q "^    $g\$" Gemfile.lock || exit 1; done` exits 0; seen to exit 1 against `main`'s `Gemfile.lock` (AC4, AC5)
- ::V7:: `test "$(mise exec -- bundle outdated --parseable | cut -d' ' -f1 | sort | tr '\n' ' ')" = 'diff-lcs marcel net-ssh prism '` exits 0; seen to exit 1 against `main` (AC7)
- ::V8:: `grep -q 'var version = "5\.8\.2"' app/assets/tailwind/daisyui.mjs` exits 0; seen to exit 1 against `main` (AC6)
- ::V9:: `mise exec -- bin/ci` passes, browser suite included (AC8)

The plan-only push leaves `scan_ruby` red, as it is on `main`; that is the issue's premise, and S4 is what turns it green. No gate builds the Docker image, so Ruby 4.0.10 there goes untested until a deploy, and nothing exercises Action Cable's server under `websocket-driver` 0.9.0, since no view subscribes to a stream.

## Open questions

None.

## Settled

None yet.
