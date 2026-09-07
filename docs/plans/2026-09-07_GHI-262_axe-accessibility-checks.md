> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: check accessibility in the system specs with axe (#262)

## Approach

Every claim below was measured on this branch before the plan was written, the way #79's plan was, and three of them contradict the issue's technical notes. The measurements were taken with the gem installed and throwaway specs under `spec/system`, then reverted so this commit lands alone.

**The dependency chain is smaller than the issue says, and safe.** `axe-core-rspec` 4.13.0 depends on `axe-core-api`, not on `axe-core-capybara`, and `axe-core-api`'s only runtime dependency is `dumb_delegator` - its `capybara`, `selenium-webdriver` and `watir` dependencies are all `:development`. Installing it pulls three gems and none of them is the `selenium-webdriver` that #79 deliberately removed. `axe-core-capybara` is not wanted here in any case: its one public method sets `Capybara.default_driver = :selenium` and builds a `Capybara::Selenium::Driver`, so the gem the issue names is the one gem that would undo the driver decision.

**`be_axe_clean` does not run on Cuprite as shipped, which is the largest departure from what the issue describes.** Two separate walls, both measured. `Axe::Core#call` asks the page whether `axe.runPartial` exists, which it does in axe-core 4.13, and takes `Axe::API::Run#analyze_post_43x`, whose first statement is `(get_selenium page).manage.timeouts.page_load`; Cuprite has no `manage`, and the run dies with `undefined method 'manage' for an instance of WebDriverScriptAdapter::QuerySelectorAdapter`. Setting `Axe::Configuration.instance.legacy_mode = true` routes around that and reaches the second wall: the legacy path calls `execute_async_script_fixed`, which unwraps driver to browser and calls `execute_async_script`, and Ferrum's method is `evaluate_async`.

The fix is not to reopen anything third-party. `Axe::Core#wrap_driver` accepts any object that answers the handful of methods its adapters probe for, so `spec/support/axe.rb` hands it a small adapter over the Capybara session that answers `execute_script`, `evaluate_script`, `find_css` and `execute_async_script`, the last delegating to `evaluate_async` with a timeout of ours. Ferrum's `evaluate_async` appends its resolver as the last argument exactly as Selenium's `execute_async_script` does, so axe's own `arguments[arguments.length - 1]` lines up untouched. Two things this buys over patching `Capybara::Cuprite::Browser`: a cuprite or ferrum upgrade that moves the method breaks loudly at the adapter instead of silently overriding a method the gem may itself have grown, and the async wait is ours rather than `Capybara.default_max_wait_time`. That second point is not theoretical - one audit measured 0.54s against a 2s default, which is a margin `.agents/testing.md`'s determinism rules should not be asked to live with, and the adapter sets 15s.

**`according_to(:wcag21aa)` would have made the whole assertion very nearly vacuous, and this is the finding that matters most.** `Axe::API::Rules#according_to` is a pass-through into axe's `runOnly: { type: :tag, values: [...] }`; it is not cumulative, so that one tag runs only the rules *introduced* at WCAG 2.1 AA. The issue's own control violation is not among them: `image-alt` in the engine the gem ships carries `["cat.text-alternatives", "wcag2a", "wcag111", ...]` and no `wcag21aa`. Measured rather than reasoned - an injected `<img>` with no `alt` stayed green under `according_to(:wcag21aa)` and went red under `according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)`. WCAG 2.1 AA is cumulative by definition, so the four tags are the correct spelling of what the issue asks for, and the list is spelled out in one place with that measurement recorded beside it. A check that passes on everything cannot be told from one that passes on nothing, and this one would have looked green forever.

**The first run found a real defect on every page.** Surveying `sessions#new`, `sign_ups#new`, the root page, `groups#edit`, `members#index` and `user_profiles#edit` under the cumulative tags returns exactly one violation, the same one each time: `html-has-lang`, serious, because `app/views/layouts/application.html.erb` opens a bare `<html>`. That is the entire markup debt this branch inherits, it is one attribute, and adding `lang` to the layout was confirmed to clear it while leaving the injected-image control red. So no rule is excluded anywhere, and the branch adds no exclusion machinery for a case that does not exist - the tag list's single home is the one place an exclusion would go if one were ever needed.

`app/views/layouts/mailer.html.erb` carries the same bare `<html>` and is deliberately left alone: axe audits browser pages, nothing in this layer would cover the change, and an untested edit to a second file is scope this issue does not ask for. Worth its own issue.

Where the assertion lands is a helper rather than a shared example, because `.agents/testing.md` prefers concrete examples and flat specs over shared machinery, and because `spec/support/paint_matcher.rb` already establishes the house shape for exactly this: a namespaced module holding the mechanism plus an `RSpec::Matchers.define` wrapper. So `be_accessible` reads beside `paint` in a spec, and its failure message is the gem's own `Audit#failure_message`, which names the rule, its impact, the offending selector and a Deque URL - reused verbatim rather than reimplemented, which is the whole reason the gem is still in the Gemfile.

`spec/rails_helper.rb` is not edited, against the issue's first criterion. `spec/support/cuprite.rb` already requires `capybara/cuprite` itself and `spec/support/paint_matcher.rb` is picked up by the support glob with no mention in that file, so a system-only matcher requiring its own gem in its own support file is the established pattern here. The alternative the criterion describes, `config.include Axe::Matchers`, would put `be_axe_clean` in the scope of every model, request and policy spec, where it cannot work.

## Steps

- Add `gem "axe-core-rspec", require: false` to the `:test` group, the flag being load-bearing rather than stylistic: the gem's entry point is named `axe-rspec` rather than `axe-core-rspec`, which Bundler's autorequire would not find, and its content is a global `config.include` this branch does not want
- Write `spec/support/axe.rb`: set `Axe::Configuration.instance.legacy_mode` and `skip_iframes`, hold the four WCAG 2.1 AA tags with the measurement that explains why all four are named, define the adapter that answers axe's four driver methods over the Capybara session with its own async timeout, and wrap `be_axe_clean` in a `be_accessible` matcher that delegates both failure messages to the gem's audit
- Add `lang` to the `<html>` element in `app/views/layouts/application.html.erb`, resolved from `I18n.locale` rather than hardcoded, as its own commit: it is a markup fix rather than test infrastructure, and it is the defect the matcher found
- Add the control spec `spec/system/axe_matcher_spec.rb` in `spec/system/paint_matcher_spec.rb`'s shape, injecting an `<img>` with no `alt` through `execute_script` for the negative case and asserting the untouched page clean for the positive one, and watch the negative case go red by giving that image an `alt` before the matcher is trusted
- Assert `be_accessible` in `spec/system/sign_in_page_spec.rb`, which is the one spec #79 left covering a screen rather than a flow or the matcher itself
- State in `.agents/testing.md`'s system-spec bullet that a screen's spec asserts `be_accessible`, naming what axe reads that the paint matcher cannot and that both stay for that reason

## Verification

- `bin/ci` exits 0
- The control's negative case exits 1 once the injected image is given an `alt`, having been seen to exit 0 without one, which is the matcher being watched red on the case it exists to catch
- The same injected image leaves `according_to(:wcag21aa)` green and `according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)` red, which is the tag list being cumulative rather than the single tag the issue names
- `bin/rspec spec/system` exits 1 with the `lang` attribute removed from the layout again, which is the assertion reaching the real pages rather than only the control's probe
- `bundle list | grep selenium` exits 1, which is the driver decision #79 took surviving this branch's new dependency
- `grep -rl "wcag2" spec/` names `spec/support/axe.rb` and nothing else, which is AC 4's one place being one place
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore 'docs/plans*' --ignore '.agents/*' --ignore 'spec/system/*' --ignore 'spec/support/*'` exits 0 over this plan

Three things no gate here can see. Whether the four tags are the right *policy* is a judgement about which standard this application holds itself to, not an exit code; the gates only prove the list is applied and that a WCAG 2.0 A violation reaches it. Whether a page is genuinely usable by someone on a screen reader is not something axe measures at all - it catches machine-checkable rules, roughly a third to a half of WCAG in Deque's own accounting, and a page with no violations can still be incoherent to navigate. And nothing here can see whether the browser suite was actually run before the pull request is marked ready, which is the trade #79 took and this branch inherits unchanged.

## Open questions

None.

## Settled

- **Does this replace `spec/support/paint_matcher.rb`?** No, and the two barely overlap. `paint` measures an element's own background composited over its first opaque ancestor, which makes it a check that a Tailwind or DaisyUI class survived the build - `bg-notacolour-999` scores exactly 1.0. axe's `color-contrast` rule measures text foreground against background and never asks whether a class compiled, so an element carrying an uncompiled class passes it green. The issue already decided both stay; this is why.

- **Which spec is "the first spec #79 wrote", per the issue's second criterion?** Genuinely ambiguous: #79's plan calls the refusal spec "the first system spec", while `spec/system/sign_in_page_spec.rb` is the only one of the four covering a screen rather than a flow or the matcher itself. The screen spec wins, because axe audits a rendered page and the issue's overview asks for the assertion on screens.

- **Is `spec/rails_helper.rb` edited, as the first criterion says?** No. The support glob already loads `spec/support/paint_matcher.rb` and `spec/support/cuprite.rb` requires its own gem, so a system-only matcher belongs in its own support file; `config.include Axe::Matchers` would leak `be_axe_clean` into every model, request and policy spec. That half of AC 1 is superseded.

- **A shared example or a helper?** A matcher, which is the helper option: `.agents/testing.md` prefers flat specs and concrete examples over shared machinery, and `spec/support/paint_matcher.rb` already sets the house shape for a system-spec assertion of this kind.

- **Is any axe rule excluded?** None. The survey found `html-has-lang` and nothing else across six pages, and that is a markup fix rather than an exclusion. AC 4 is satisfied by the tag list having exactly one home rather than by any rule being named there.

- **Does the mailer layout's identical bare `<html>` get fixed here?** No. Nothing in this layer would cover it, and an untested edit to a second file is scope this issue does not ask for. It wants its own issue.

- **The issue's technical notes need amending, the way #79 amended its own.** Three claims in them are wrong: that `axe-core-rspec` pulls `axe-core-capybara`, that it therefore runs on Cuprite unchanged, and that `according_to(:wcag21aa)` expresses WCAG 2.1 AA. The body is not edited from inside this chain; it is named here for the owner.
