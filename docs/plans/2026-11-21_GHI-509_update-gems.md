> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update net-ssh, image_processing and webmock (#509)

## Approach

The inventory taken on 2026-11-21, per `.agents/dependencies.md`, found three gems that can move and nothing else: the toolchain, Node, the npm packages, the GitHub Actions majors, the vendored daisyUI, the Litestream image and the importmap pins are current (N4), so the round is steps 4 and 5 of *The update order* alone. Every command runs as `mise exec -- <command>`.

`net-ssh` 7.3.10 moves first, in its own commit, because it is what turns `scan_ruby` green. Its 7.3.x changelog carries the two advisories' fixes backported from 8.1.1 and 8.1.2: a `@revoked` known_hosts entry raises `Net::SSH::HostKeyRevoked`, and `Net::SSH::Proxy::HTTPS` verifies the proxy's certificate. `net-ssh` is reached only through `kamal` and its `sshkit`, at deploy time, and the `ssh:` block in `config/deploy.yml` sets no proxy, so neither fix changes a deploy here; no gate in this round exercises it either.

`image_processing` 2.2.1 and `webmock` 3.37.0 move together in the next commit. `image_processing` 2.2.1 is a security release too, closing a remote code execution where operation names come from user input, though no advisory names it yet; the app's one attachment, the feedback screenshots in `app/models/feedback.rb`, is never transformed into a variant or preview, and nothing calls `ImageProcessing`, so it reaches no code here. `webmock` 3.37.0 adds `WebMock.executed_requests` and fixes Curb stub matching, neither of which a spec here relies on.

No package in the round ships markup or CSS, so the changelog impact check has nothing to list.

## Steps

- ::S1:: `mise exec -- bundle update --conservative net-ssh`, in its own commit, then `mise exec -- bin/bundler-audit`
- ::S2:: `mise exec -- bundle update --conservative image_processing webmock`, in one commit
- ::S3:: Check the `Gemfile.lock` diff against `main` by eye: only the three named gems moved, each with its checksum line
- ::S4:: If `--conservative` refuses a gem or drags in one that is not named, update the issue's AC1 and AC4 to match and name the change on the pull request

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-509_update-gems.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-509_update-gems.md` exits 0
- ::V3:: `test "$(git diff main -- Gemfile.lock | grep -E '^[-+] ' | grep -vE '^[-+]    (net-ssh \(7\.3\.(8|10)\)|image_processing \(2\.2\.[01]\)|webmock \(3\.3[67]\.0\))$' | grep -vE '^[-+]  (net-ssh \(7\.3\.(8|10)\)|image_processing \(2\.2\.[01]\)|webmock \(3\.3[67]\.0\)) sha256=' | wc -l)" = 0 && grep -q '^    net-ssh (7\.3\.10)$' Gemfile.lock && grep -q '^    image_processing (2\.2\.1)$' Gemfile.lock && grep -q '^    webmock (3\.37\.0)$' Gemfile.lock` exits 0; seen to exit 1 against `main`'s `Gemfile.lock` (AC1)
- ::V4:: `mise exec -- bin/bundler-audit` exits 0; seen to exit 1 on `main`'s `net-ssh` 7.3.8 (AC2)
- ::V5:: `test "$(mise exec -- bundle outdated --parseable | grep . | cut -d' ' -f1 | sort | tr '\n' ' ')" = 'diff-lcs marcel net-ssh prism '` exits 0; seen to exit 1 against `main` (AC4)
- ::V6:: `mise exec -- bin/ci` passes, browser suite included (AC3)

The plan-only push leaves `scan_ruby` red, as it is on `main`, and S1 turns it green. No gate runs a deploy, so `net-ssh` 7.3.10 goes untested until the next `bin/kamal deploy`.

## Open questions

None.

## Settled

None yet.
