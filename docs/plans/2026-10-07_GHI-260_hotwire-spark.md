> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: reload the browser on change with hotwire-spark (#260)

## Approach

`hotwire-spark` joins the existing `group :development` block of `Gemfile`, in alphabetical place between `annotaterb` and `ruby-lsp-rspec`, with a one-line comment and link like its neighbours, and `bundle install` locks it. No configuration follows: its defaults already watch `app/views`, `app/assets/builds` (where `tailwindcss-rails` writes its build) and `app/javascript/controllers`, `config/cable.yml` gives development the `async` adapter its channel needs, and `config/initializers/content_security_policy.rb` is wholly commented out, so nothing blocks its WebSocket. Because the gem is never required outside development, the test suite and production are untouched by construction, and the runner checks below prove it rather than assume it.

The behaviour criterion is proven in headless Chromium against a running `bin/dev`, by a scratch script that sets a marker on `window`, then edits a view, the stylesheet and a Stimulus controller in turn and asserts that each change reaches the open page while the marker survives, which is what tells an in-place update from a full reload. The probes are `app/views/sessions/new.html.erb` gaining an element mounted on the unused `hello` controller, a rule for that element in `app/assets/tailwind/application.css`, and a changed greeting in `app/javascript/controllers/hello_controller.js`; the script restores all three files whatever its outcome, so none of the probes is committed.

## Steps

- Add `gem "hotwire-spark"` to the `group :development` block of `Gemfile` with a comment naming what it does and linking https://github.com/hotwired/spark, then run `bundle install`
- Read the `Gemfile.lock` diff against `main`: only `hotwire-spark`, its runtime dependencies new to the lock (`listen` and what `listen` pulls in) and their `CHECKSUMS` lines may appear, and nothing already locked may move
- Run the development, test and production runner checks, then the mutation: the gem moved temporarily to the top level of `Gemfile`, where the test and production checks must exit 1, then moved back
- Write the scratch live-reload script in the session scratchpad, run it once on `main`'s code before the gem is installed to see it fail, then on this branch to see it pass
- Run `bin/ci` in this worktree

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-07_GHI-260_hotwire-spark.md` exits 0
- `bundle exec ruby -e 'exit Bundler.definition.dependencies.find { _1.name == "hotwire-spark" }&.groups == [:development]'` exits 0, having been seen to exit 1 on `main`
- `bundle exec rails runner 'p defined?(Hotwire::Spark); exit !!defined?(Hotwire::Spark)'` prints `"constant"` and exits 0 in development, having been seen to print `nil` and exit 1 on `main`
- `RAILS_ENV=test bundle exec rails runner 'p defined?(Hotwire::Spark); exit !defined?(Hotwire::Spark)'` prints `nil` and exits 0, and the same with `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1` does too; both pass on `main` as well, so each was seen to exit 1 with the gem moved temporarily out of the `development` group
- The scratch live-reload script exits 0 against `bin/dev` on this branch, with the view, the stylesheet and the Stimulus controller each reaching the open page and the `window` marker intact after all three, having been seen to exit 1 on `main`'s code at the first of them
- `bin/ci` is green
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-10-07_GHI-260_hotwire-spark.md` exits 0

The live-reload script proves the defaults on one page, in headless Chromium, for the three file kinds the issue names; it cannot see the upstream defects the issue's technical notes record, such as the `Content-Length` truncation in hotwired/spark#103, which only shows on whatever page and response size triggers it. Whether working with the reload feels better is the owner's to judge in their own browser.

## Open questions

None.

## Settled

None yet.
