> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add the first system specs with local signoff (#79)

## Approach

The decision record `docs/adr/2026-09-04_browser-verification_0005.md` settles what this layer is: Cuprite over the DevTools Protocol, specs in `spec/system`, run from `bin/ci` on a developer machine rather than on a runner. What it does not settle is how a suite that must never run on a runner stays off one, and that turns out to be the cheapest part of the whole change. Where this plan departs from that record is reporting, which it decided would be `gh signoff`; the departure is argued below and amended in the record itself rather than left as a discrepancy.

`.github/workflows/ci.yml`'s `test` job runs `bin/rspec` with no arguments. So the exclusion belongs in `.rspec`, where every bare invocation inherits it: the runner, a developer, and an agent that reaches for the suite without reading this file. `config/ci.rb` then names the directory explicitly and clears the exclusion for that one step. Measured before this plan was written, on a throwaway spec under `spec/system`: the bare suite reports 565 examples, the same run with the exclusion reports 564, and an explicit path with the exclusion cleared reports 1. **The workflow file is therefore not edited at all**, which matters more than it looks: adding or renaming a job means moving `required_status_checks` in the same change, and touching nothing means the four pinned contexts keep reporting exactly as they do now.

Two premises the issue carries do not survive contact with the code, and both are cheap to satisfy properly rather than work around.

Screenshots do not land in `tmp/capybara` by themselves. Rails' screenshot helper resolves its directory as `Capybara.save_path.presence || "tmp/screenshots"`, and Capybara ships that setting empty, so an unconfigured suite writes to `tmp/screenshots`. Setting `Capybara.save_path` is one line and makes the issue's criterion true rather than approximately true. Nothing needs a new ignore rule, because `.gitignore` already excludes the whole of `tmp` bar its keepfiles.

`gh signoff` is not used at all, which is the largest departure from what the issue and the decision record describe. With branch protection left alone there is no required context for it to satisfy, so it would post a green status that nothing reads, and a green mark nothing reads is what ADR 0001 rejected when it deleted the `system-test` job. The commented signoff block in `config/ci.rb` is therefore removed rather than uncommented, since a commented block that has been decided against reads as a plan for later. This supersedes the section of ADR 0005 that decides `gh signoff` reports the suite, so that record is amended here rather than quietly contradicted.

Signing a user in needs its own answer here, because the existing `sign_in_as` helper writes a signed cookie through a rack-test request and a Cuprite session never sees it: the browser is a separate process with its own cookie jar. Authentication in this application is passwordless, so there is no form to fill either. `POST /session` only mails a link, and the mail is enqueued rather than delivered.

None of the reference codebases injects a cookie: `basecamp_once-campfire` and `basecamp_writebook` drive the real sign-in form, and `basecamp_fizzy` visits a real shipped route whose controller sets the real signed cookie. This repository does not follow them, and the reason is a difference in the suites rather than a disagreement about taste. Those suites are eighteen tests, eight and two; `.agents/testing.md` asks for a system spec per view and per flow, so this one is built to grow. Every one of those specs needs a signed-in member, because everything in this application except authentication itself sits behind it, and Fizzy's own shortcut still costs two navigations. What does not amortise at eighteen tests does dominate at a hundred.

So there are two helpers, and the split is the point. One drives the whole passwordless cycle through the browser, minting a token, visiting the emailed link's URL and pressing the confirmation button, and it is used by the one or two specs whose subject *is* authentication. Everything else sets the session cookie directly through the driver. That is not new knowledge in the test suite: the existing `sign_in_as` already builds the signed value through `ActionDispatch::TestRequest`, so the browser helper is that same computation handed to the driver's cookie API rather than to a rack-test request, and the signing scheme stays in exactly one place.

The paint matcher goes further than anything in those suites. Fizzy is the only one of the four with a computed-style assertion at all, and it reads `getComputedStyle(...).backgroundColor` directly, which is exactly the reading the decision record rejects: a translucent fill is reported uncomposited, so the number describes a colour nobody sees. Compositing over the first opaque ancestor is what this repository adds.

The paint matcher is the reason this layer exists at all, so it carries its own control. An uncompiled utility class and a colour identical to its background both report a contrast ratio of exactly 1.0, which means a passing control proves two separate things: that the matcher measures, and that the class under test survived the Tailwind build. Per `.agents/testing.md` the control is watched red before it is trusted, and the way to watch it is to point it at a class that does compile and see the run go red.

Branch protection is not touched, and that is the first of two deliberate narrowings of what the issue asked for. Requiring a context would make every open pull request need one from that moment, branches cut before the change included, with `enforce_admins` on and no admin override. What it would buy over a `## Verification` box is only that the box cannot be ticked untruthfully, which is the same trust a status posted from a laptop already asks for, so it buys less than its blast radius costs. The gate is therefore the checkbox, which `merge` already refuses on, and `.agents/testing.md` carries the requirement in prose for the next reader.

## Steps

- Swap the driver gem: `selenium-webdriver` leaves the `:test` group and `cuprite` replaces it, with a `spec/support` file that requires `capybara/cuprite`, sets `driven_by :cuprite` for `type: :system`, and points `Capybara.save_path` at `tmp/capybara`
- Keep the browser suite out of every bare RSpec run by adding the system exclusion to `.rspec`, leaving `.github/workflows/ci.yml` untouched
- Replace the two commented Minitest lines in `config/ci.rb` with a live system-spec step after the RSpec step, and delete the commented signoff block rather than uncommenting it
- Add the paint matcher to `spec/support`: composite the element's computed background over the first ancestor whose own background is opaque, read the pixel back, and report the WCAG contrast ratio against that surface
- Add the control spec asserting an uncompiled utility class does not paint, and watch it go red against a class that does compile before trusting it
- Add two sign-in helpers for `type: :system`, beside the existing request-spec ones: one that sets the signed session cookie straight through the driver, reusing the value the current `sign_in_as` already computes so the signing scheme stays in one place, and one that drives the whole passwordless cycle by minting a token, visiting the link's URL and pressing the confirmation button
- Write one spec whose subject is the authentication cycle itself and have it use the browser helper, so the flow the cookie helper skips is covered somewhere rather than nowhere
- Write the first system spec for the refusal path: a paused member submitting the group edit form lands on the root page and the alert paints, asserting only what a browser adds over the request specs that already cover the redirect and the message
- Point Cuprite at Chromium explicitly rather than letting Ferrum search, resolving the binary from a documented environment variable and falling back to the usual Chromium names, and have `bin/setup` fail loudly when neither finds one
- Add `rubocop-capybara` to the `:test` group and load it as a plugin beside `rubocop-rspec`, which no longer carries the Capybara cops, then read its cop list and configure anything that fights the Determinism rules rather than working around it
- Record in `.agents/testing.md` what implementing the layer taught, and remove every transitional sentence about it: the Framework choices line names the driver without naming what it replaced, and the system-spec bullet states the conventions without citing the issue that built them
- State in `.agents/testing.md` that running the browser suite before marking a pull request ready is required, since nothing enforces it once branch protection is left alone, and that a spec signs in through the cookie helper unless authentication is its subject
- Correct the CI check-run section of `.agents/gh-solo.md` to say the browser suite has no check of its own at all, replacing both the anticipated `system-test` name and its `-1` pin
- Amend `docs/adr/2026-09-04_browser-verification_0005.md` where it decides `gh signoff` reports the suite, rewriting that section to the current answer and keeping what it recorded as history, the way 0005 itself amended 0001

## Verification

- `bin/ci` passes
- `bin/rspec` and `bin/rspec --exclude-pattern "system/**/*_spec.rb"` report the same example count, which is the exclusion covering every bare invocation including the runner's
- `bin/rspec --exclude-pattern "" spec/system` reports a non-zero example count, which is the same exclusion being overridable for the one step that needs it
- The control spec exits 1 when pointed at a utility class that does compile, having been seen to exit 0 against the uncompiled one
- The refusal spec exits 1 when `layouts/_flash.html.erb` has its `alert` branch removed, which is the defect this layer exists to catch
- `test -n "$(ls tmp/capybara)"` exits 0 after a deliberately failed system spec, which is the screenshot landing where the issue asks for it
- `bin/setup --skip-server` exits non-zero when no Chromium binary is discoverable, watched against a run where the binary is reachable
- `bin/rspec --exclude-pattern "" spec/system` exits 0 on this branch's HEAD, which is the browser suite itself and the gate that replaces the required check
- `gh pr checks` lists exactly the four contexts it lists today, which is branch protection having been left alone
- `grep -ri signoff config/ bin/ .github/` exits 1, which is the reporting mechanism having been removed rather than left commented out
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore 'docs/plans*' --ignore '.agents/*' --ignore 'spec/system/*' --ignore 'spec/support/*'` exits 0 over this plan

Two things no gate here can see. Whether the paint matcher measures what a person actually sees is a judgement about compositing, not an exit code: the control proves the matcher is live and the ratio is real, but a wrong opaque-ancestor walk would still produce a confident number. And nothing here can see whether the browser suite was actually run before a pull request is marked ready, because the gate for it is a checkbox rather than a required check. That is the trade this branch takes deliberately, and it is a wider version of the trust the decision record already accepted for a laptop-posted signoff. The first arrival of a second committer is the point to revisit both.

## Open questions

- The issue's own title, and this plan's, still say "with local signoff", which the branch no longer does. Renaming the issue costs nothing; renaming the branch and the plan file mid-branch costs more than the confusion is worth, so the plan proposes leaving both and correcting the issue.
- `spec/rails_helper.rb` blocks outbound HTTP with `WebMock.disable_net_connect!(allow_localhost: true)`, and the allowance should cover both Capybara's server and Cuprite's DevTools socket. `basecamp_once-campfire` nonetheless disables WebMock outright in its system-test base class, so if the first spec cannot reach the browser this is the first thing to suspect rather than the driver.

## Settled

- **Should branch protection require the signoff context, as the issue's fifth criterion asks?** No. The gate is the `## Verification` checkbox, which `merge` already refuses on, and `.agents/testing.md` states the requirement in prose. Requiring the context would have made every open pull request need a signoff from that moment, with `enforce_admins` on and no admin override, and it buys only that the box cannot be ticked untruthfully, which is the same trust a laptop-posted signoff already asks for. The issue's fifth acceptance criterion is superseded and needs amending.

- **Is `gh signoff` used at all, once nothing requires its context?** No. It would post a green status no gate reads, which is what ADR 0001 rejected in deleting the `system-test` job, so the commented block in `config/ci.rb` is deleted rather than uncommented and the extension is not needed. This supersedes the section of ADR 0005 deciding that `gh signoff` reports this suite, which is amended by a step above rather than left contradicted, and it makes the issue's fourth acceptance criterion wrong as well as its fifth.

- **Does every system spec sign in through the browser?** No: only a spec whose subject is authentication. Every other spec sets the session cookie through the driver, because everything in this application except authentication sits behind it, so a browser sign-in per spec is a cost the whole suite pays forever. The reference suites are small enough that it never mattered to them; this one is built to grow to a spec per view and per flow.
