> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add the first system specs with local signoff (#79)

## Approach

The decision record `docs/adr/2026-09-04_browser-verification_0005.md` settles what this layer is: Cuprite over the DevTools Protocol, a handful of specs in `spec/system`, run from `bin/ci` on a developer machine, reported to the pull request by `gh signoff` rather than by a runner job. What it does not settle is how a suite that must never run on a runner stays off one, and that turns out to be the cheapest part of the whole change.

`.github/workflows/ci.yml`'s `test` job runs `bin/rspec` with no arguments. So the exclusion belongs in `.rspec`, where every bare invocation inherits it: the runner, a developer, and an agent that reaches for the suite without reading this file. `config/ci.rb` then names the directory explicitly and clears the exclusion for that one step. Measured before this plan was written, on a throwaway spec under `spec/system`: the bare suite reports 565 examples, the same run with the exclusion reports 564, and an explicit path with the exclusion cleared reports 1. **The workflow file is therefore not edited at all**, which matters more than it looks: adding or renaming a job means moving `required_status_checks` in the same change, and touching nothing means the four pinned contexts keep reporting exactly as they do now.

Two premises the issue carries do not survive contact with the code, and both are cheap to satisfy properly rather than work around.

Screenshots do not land in `tmp/capybara` by themselves. Rails' screenshot helper resolves its directory as `Capybara.save_path.presence || "tmp/screenshots"`, and Capybara ships that setting empty, so an unconfigured suite writes to `tmp/screenshots`. Setting `Capybara.save_path` is one line and makes the issue's criterion true rather than approximately true. Nothing needs a new ignore rule, because `.gitignore` already excludes the whole of `tmp` bar its keepfiles.

The signoff context is not a name this repository invents, and it is not a name it configures either: the extension composes the context from a positional argument, so `gh signoff` posts `signoff` and `gh signoff <name>` posts `signoff/<name>`. The commented block in `config/ci.rb` runs the bare form, so it needs the argument added. Both helpers that block calls, `success?` and `failure`, exist in the Active Support version this application resolves, so uncommenting it is safe.

Signing a user in needs its own answer here, because the existing `sign_in_as` helper writes a signed cookie through a rack-test request and a Cuprite session never sees it: the browser is a separate process with its own cookie jar. Authentication in this application is passwordless, so there is no form to fill either. `POST /session` only mails a link, and the mail is enqueued rather than delivered.

The reference codebases answer this consistently and none of them injects a cookie. `basecamp_once-campfire` and `basecamp_writebook` both drive the real sign-in form. `basecamp_fizzy` is the closest match, because its own flow is multi-step in the same way this one is, and its system tests still go through the browser: they visit a real shipped route whose controller sets the real signed cookie, rather than reaching for the driver's cookie API. So the route taken here is the same shape as Fizzy's. Mint a token, visit the emailed link's own URL, and press the button the confirmation page already renders. Two real navigations through the real controllers, exercising the one flow every other system spec depends on.

The paint matcher goes further than anything in those suites. Fizzy is the only one of the four with a computed-style assertion at all, and it reads `getComputedStyle(...).backgroundColor` directly, which is exactly the reading the decision record rejects: a translucent fill is reported uncomposited, so the number describes a colour nobody sees. Compositing over the first opaque ancestor is what this repository adds.

The paint matcher is the reason this layer exists at all, so it carries its own control. An uncompiled utility class and a colour identical to its background both report a contrast ratio of exactly 1.0, which means a passing control proves two separate things: that the matcher measures, and that the class under test survived the Tailwind build. Per `.agents/testing.md` the control is watched red before it is trusted, and the way to watch it is to point it at a class that does compile and see the run go red.

The branch protection change is last, and it is the one step with a blast radius beyond this branch. `enforce_admins` is on and there is no way to merge past a check that never reports, so the context name has to be read off a signoff that actually posted before it is required of anything. That ordering is a step in its own right below rather than a note, because getting it backwards blocks every open pull request with no admin override.

## Steps

- Swap the driver gem: `selenium-webdriver` leaves the `:test` group and `cuprite` replaces it, with a `spec/support` file that requires `capybara/cuprite`, sets `driven_by :cuprite` for `type: :system`, and points `Capybara.save_path` at `tmp/capybara`
- Keep the browser suite out of every bare RSpec run by adding the system exclusion to `.rspec`, leaving `.github/workflows/ci.yml` untouched
- Replace the two commented Minitest lines in `config/ci.rb` with a live system-spec step after the RSpec step, and uncomment the signoff block with the context name given as a positional argument
- Add the paint matcher to `spec/support`: composite the element's computed background over the first ancestor whose own background is opaque, read the pixel back, and report the WCAG contrast ratio against that surface
- Add the control spec asserting an uncompiled utility class does not paint, and watch it go red against a class that does compile before trusting it
- Add a browser sign-in helper that mints a sign-in token, visits the link's URL and completes the confirmation, wired to `type: :system` alongside the existing request-spec helpers
- Write the first system spec for the refusal path: a paused member submitting the group edit form lands on the root page and the alert paints, asserting only what a browser adds over the request specs that already cover the redirect and the message
- Point Cuprite at Chromium explicitly rather than letting Ferrum search, resolving the binary from a documented environment variable and falling back to the usual Chromium names, and have `bin/setup` fail loudly when neither finds one
- Record in `.agents/testing.md` what implementing the layer taught, and remove every transitional sentence about it: the Framework choices line names the driver without naming what it replaced, and the system-spec bullet states the conventions without citing the issue that built them
- Correct the CI check-run section of `.agents/gh-solo.md` to name the signoff context as it now exists, replacing the anticipated `system-test` name
- Last, and only after a signoff has posted on this pull request and its context has been read back from it, add that context to `required_status_checks` with `app_id: -1`

## Verification

- `bin/ci` passes
- `bin/rspec` and `bin/rspec --exclude-pattern "system/**/*_spec.rb"` report the same example count, which is the exclusion covering every bare invocation including the runner's
- `bin/rspec --exclude-pattern "" spec/system` reports a non-zero example count, which is the same exclusion being overridable for the one step that needs it
- The control spec exits 1 when pointed at a utility class that does compile, having been seen to exit 0 against the uncompiled one
- The refusal spec exits 1 when `layouts/_flash.html.erb` has its `alert` branch removed, which is the defect this layer exists to catch
- `test -n "$(ls tmp/capybara)"` exits 0 after a deliberately failed system spec, which is the screenshot landing where the issue asks for it
- `bin/setup --skip-server` exits non-zero when no Chromium binary is discoverable, watched against a run where the binary is reachable
- `gh signoff status` reports a posted context for this branch's HEAD, and `gh pr checks` names it, before any branch protection change is made
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore 'docs/plans*' --ignore '.agents/*' --ignore 'spec/system/*' --ignore 'spec/support/*'` exits 0 over this plan

Two things no gate here can see. Whether the paint matcher measures what a person actually sees is a judgement about compositing, not an exit code: the control proves the matcher is live and the ratio is real, but a wrong opaque-ancestor walk would still produce a confident number. And a locally posted signoff is a trust claim with no artifact trail, which the decision record accepts deliberately for a repository with one committer; nothing in this branch changes that, and the first arrival of a second committer is the point to revisit it.

## Open questions

- The context name is the owner's to choose, and it is permanent once branch protection requires it. `system` keeps the suite's own word; `system-test` preserves the name ADR 0001 anticipated and the one `.agents/gh-solo.md` currently carries, at the cost of implying a job that no longer exists. The plan writes whichever is chosen into both files and into protection.
- The commented block posts nothing on the failure branch: `failure` prints locally while `gh signoff fail` would leave a red mark on the commit. The decision record's trust argument leans on that red mark existing, but the issue's criteria never ask for it, so adding it is scope the owner should grant rather than the plan assume.
- `spec/rails_helper.rb` blocks outbound HTTP with `WebMock.disable_net_connect!(allow_localhost: true)`, and the allowance should cover both Capybara's server and Cuprite's DevTools socket. `basecamp_once-campfire` nonetheless disables WebMock outright in its system-test base class, so if the first spec cannot reach the browser this is the first thing to suspect rather than the driver.

## Settled

None yet.
