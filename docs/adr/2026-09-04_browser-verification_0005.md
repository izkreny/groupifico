> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0005. Browser verification

## Status

Accepted, 2026-09-04. Amends two paragraphs of `2026-08-20_github-repository-conventions_0001.md`: the one that called local signoff for `system-test` "a preference to be tested rather than a settled rule", which this record settles, and the section saying the job "comes back as its own job", which this record replaces with no runner job at all. Both paragraphs stay, since the history they record is true, and each now points here.

Records the decisions #79 builds, so that #79 cites this file rather than carrying the reasoning.

## Context

`ApplicationController#deny_access` shipped from #172 with two defects the request-spec layer could not see. `layouts/_flash.html.erb` rendered `notice` and nothing else, so every alert the application had ever set was discarded silently, the sign-in rate limiter's included. And `deny_access` used `redirect_back_or_to`, whose referer for a refused write is the page that refused it, so a paused member submitting the edit form landed back on that form. Both passed the request specs: a request spec sends no `Referer`, so the redirect fell through to `root_path` and read as correct, and the spec asserted `flash[:alert]`, the value in the hash, which was right the whole time the layout was throwing it away.

A ~200-line Node script driving Chromium over the DevTools Protocol, with no dependency beyond Node's global `WebSocket`, found both in one pass. It is attached to #186 rather than committed. The check that mattered was not "is the alert in the DOM" but "does the alert paint": the script composited the element's background over the first opaque ancestor on a 1x1 canvas and read the pixel back, so a translucent fill was measured as a person sees it rather than as `getComputedStyle` reports it. That is the class of defect a browser exists to catch, and it is the class an agent changing a view has no other way to see.

Two questions followed. Whether that script earns a place in the repository beside the system-spec layer #79 was already going to build on `capybara` and `selenium-webdriver`, both waiting in the Gemfile. And, since `.agents/testing.md` keeps the system layer to a few critical happy paths, how an agent verifying its own frontend work avoids rewriting the same checks every time.

## Decision

### One mechanism, and the harness's checks become system specs

The Node script is not committed. Its checks are re-expressed as Capybara system specs in `spec/system`, and its two measuring techniques become helper code the whole suite shares.

None of the reference codebases keeps a browser-driving script outside its test suite: not `basecamp_fizzy`, `basecamp_once-campfire`, `basecamp_writebook` or `hitobito_hitobito`, in `script/`, `bin/` or `lib/tasks`. A second browser stack that the suite never runs rots the first time a form changes, and the value the script carried, the paint check and the traps below, survives the move because the driver chosen next is the same protocol underneath.

### Cuprite, not Selenium

`selenium-webdriver` leaves the Gemfile; `cuprite` replaces it, with `driven_by :cuprite`. Same Capybara API, so nothing in the Determinism section of `.agents/testing.md` changes.

The survey behind it, each repository read from source rather than recalled, per the standing rule in `CLAUDE.md` that `rails_rails` outranks everything on framework capability and `basecamp_*` gets preference on application patterns:

| Repository | Browser tests | Driver | Size | CI |
|------------|---------------|--------|------|----|
| `basecamp_fizzy` | `test/system` | Selenium, headless Chrome, headed via env toggle | 5 files / 18 tests | step in the `test` job |
| `basecamp_once-campfire` | `test/system` | Selenium, `using: :headless_chrome` | 3 files / 8 tests | dedicated `test_system` job |
| `basecamp_writebook` | `test/system` | Selenium, `using: :headless_chrome` | 2 files | one job, installs `google-chrome-stable`, keeps failure screenshots |
| `hitobito_hitobito` | `spec/features` | Selenium, custom `:chrome` driver | 69 files / ~337 examples | dedicated `feature-specs` job |
| `rails_rails`, `rails new` | generates a `test/system` skeleton | Selenium, `using: :headless_chrome`, 1400x1400 | n/a | n/a |
| `steveclarke_real-world-rails`, 196 apps | `spec/features` 71, `spec/system` 22, `test/system` 21 | Selenium 65, Poltergeist 25, Cuprite 15, `capybara-playwright-driver` 12, Node Playwright ~19, Cypress ~4 | varies | ~12 run `test:system` explicitly |

The framework default is Selenium with headless Chrome, and every Basecamp application takes it unchanged. Three things in the survey outweigh that default here.

The Basecamp suites are two to five files each, and the Rails testing guide now says system tests are to be used sparingly and no longer generates them from a scaffold. That is the size `.agents/testing.md` already asks for, so the suite will be small enough that the driver's ergonomics matter less than its footprint.

Cuprite is the one alternative the guide documents, in the same section that documents the default: add the gem, `require "capybara/cuprite"`, `driven_by :cuprite`. Everything else in the corpus is dead (Poltergeist, Apparition) or a second runtime (Playwright, Cypress) that a suite of a few files does not pay for.

Selenium drives Chrome through a version-matched `chromedriver` binary, which is why `basecamp_writebook`'s workflow installs the browser itself before the suite runs. Cuprite drives Chromium over the DevTools Protocol directly, through Ferrum, which is what #172's script already did with nothing installed beyond the browser. The paint check ports as it stands, through `page.evaluate_script`, because it was CDP all along.

### The suite runs locally, and `gh signoff` reports it

`spec/system` runs from `bin/ci` on the owner's machine and never on a GitHub Actions runner. There is no `system-test` job in `.github/workflows/ci.yml`, and #79 does not add one.

`gh-signoff` is the mechanism `config/ci.rb` already carries commented out: when `bin/ci` passes, `gh signoff` posts a green commit status on the pushed HEAD, and branch protection requires it. Its README, read from the `basecamp/gh-signoff` repository, fixes one fact this repository's earlier documents got wrong. **The status context it posts is `signoff`, or `signoff/<name>` for a named context, never a name of the repository's choosing.** So the required check cannot be called `system-test`, as ADR 0001 and `.agents/gh-solo.md` anticipated; it is `signoff/<name>`, added to `required_status_checks` with `app_id: -1`. That value is the API's documented "explicitly allow any app"; a status posted from a laptop is by definition not from GitHub Actions, so the check cannot carry the `15368` pin the other four do, and omitting the id is not the same thing, since the API then pins the check to whichever app reported it last. ADR 0001 has the longer account. The README also records that a signoff refuses unless HEAD is contained in the pushed ref, that `gh signoff fail` leaves a red status when a run fails, and that its `install` subcommand creates a ruleset rather than editing legacy branch protection; this repository stays on the branch protection it has and adds the context by hand, which the README says its `check` and `status` commands still read.

Why local rather than a runner: a browser suite is the slowest thing in the gate and the one most likely to need a real display to debug, a laptop already has the browser and the seeded database, and a solo repository has nobody for a runner's audit trail to convince. The cost is named under Consequences.

### What the suite carries, so an agent stops rewriting it

Each of these was met in practice while writing #172's script, and each is helper code in `spec/support`, not prose, because prose is what an agent rewrites from memory.

- **A paint matcher.** `expect(page).to paint("#alert")`, or its equivalent: composite the element's computed background over the first ancestor whose background is opaque, read the pixel back, and compute the WCAG contrast ratio against that surface. `getComputedStyle` reports a translucent colour uncomposited, so a ratio taken from it describes a colour nobody sees. `document.body` is transparent in this application, and a canvas filled with a transparent colour keeps the previous pixel, which reads as "subject equals surface" and fails for the wrong reason; walking up to the first painting ancestor is what makes the number true.
- **A control watched failing.** A spec asserting that a utility class Tailwind never compiled does *not* paint. An uncompiled class reports a ratio of exactly 1.0, indistinguishable from a colour identical to the background, so a passing control proves two things at once: the matcher works, and the real class exists in the build. Per `.agents/testing.md`, it is watched red before it is trusted.
- **Waiting on the condition, not the document.** Turbo navigates without ever leaving `document.readyState === "complete"`, so a wait on the document returns at once and every later assertion races the navigation. Capybara's own waiting matchers already do the right thing; the trap is any helper that reaches past them to the document.

## Consequences

**`selenium-webdriver` leaves and `cuprite` arrives**, in #79, which also names a Chromium binary as a local development prerequisite, in `bin/setup` or the README, since nothing in the Gemfile provides one.

**#79 changes shape.** Its title and criteria described a fifth runner job with screenshots uploaded from the workflow run. They now describe `bin/ci` running the suite, `gh signoff` posting the check, screenshots in `tmp/capybara`, and installing the extension as a step the owner runs, since an install is never an agent's to perform.

**`bin/ci` includes the suite, or "local only" decays into "never".** A suite that only runs when somebody remembers is not a gate. This is #79's criterion, and the reason the signoff step in `config/ci.rb` sits after the tests rather than beside them.

**A locally posted status is a trust claim with no artifact trail.** A runner leaves logs and screenshots anyone can open; a signoff leaves a green tick and the owner's word. In a repository with one committer that is the same trust the four pinned checks already extend to whoever pushed, and `gh signoff fail` at least leaves a red mark when the run fails. If a second committer ever arrives, this is the first decision to revisit.

**The two paragraphs of ADR 0001 named under Status each gain a sentence pointing here**, and `.agents/gh-solo.md`'s note that `system-test` "takes `-1`" is corrected to the `signoff/<name>` context when #79 adds the check, so that the name in the file is the name in branch protection.

**`.agents/testing.md` stops deferring its system-spec conventions to #79.** The conventions are this record; #79 adds what implementing them teaches.
