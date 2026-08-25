# Testing conventions for this repository

The rules specs are written and reviewed against. This file wins on any conflict about testing. The suite's model layer already exists on `main` - model specs and factories - and the layers above it have arrived with #149; this file predates them so that work is reviewed against agreed rules instead of establishing them mid-diff. A spec that predates a rule here gets aligned when next touched, never in bulk. The local gate and CI facts live in [`.agents/github.md`](github.md).

## Framework choices

RSpec (`rspec-rails`) with FactoryBot (`factory_bot_rails`), plus `capybara` and `selenium-webdriver` waiting in the Gemfile for the system layer. This is a deliberate deviation from the 37signals default of Minitest with fixtures, and no alignment pass "fixes" it: testing is where this repository keeps its own choices.

## Philosophy

Kent Beck's, without the test-first ordering. Tests ship in the same commit or PR as the behavior they cover, not before, not later; security fixes always include a regression test.

- **A test is an executable specification.** Every example answers "in scenario X, what should happen". "It works correctly" is not a description.
- **Test behavior, not implementation**, so tests survive refactoring.
- **Never add production complexity for testability.** No test-induced design damage.
- **Watch a new test fail once**, on the pre-fix input or the wrong value. A test never seen red proves nothing.
- **Never mix behavior changes with refactoring**, in the code or in the specs.

## Spec layers and what each covers

- **Model specs** for validations, associations and domain logic. This is where business outcomes are asserted. Validations and associations use the installed `shoulda-matchers` one-liners; hand-rolled checks are for behavior the matchers cannot express.
- **Request specs** for controller behavior: one file per controller, every action covered, over real HTTP. No controller specs, ever: request specs are the one layer that covers controllers.
- **Helper specs** for helpers that carry logic.
- **System specs**: a few critical happy paths only; one smoke test can cover a whole flow. The system layer, its CI job and its first specs belong to #79; this file defines no further system-spec conventions until that lands - only the Determinism section's Capybara seed rules below.
- **View specs**: banned by default. The one carve-out, judged case by case on the PR, is a partial carrying conditional or permission logic that request specs cannot easily reach - the pattern the few real-world heavy users of the layer (gitlabhq, identity-idp, alaveteli) reserve it for. Routine views are covered by request specs asserting the key HTML, and by system specs.

**Never duplicate the same behavior assertion at multiple layers.** A request spec asserts the visible outcome: `expect(response).to redirect_to(order_path(Order.sole))` at most. The business outcome belongs in a model spec that builds its own record: `order = create(:order, items: two_items); expect(order.total).to eq(90)`.

## The signed-in/signed-out pairing pattern

Every controller action is asserted in two contexts, signed in and not signed in. The signed-out surface is whatever declares `allow_unauthenticated_access` - today the login page (`sessions#new`/`#create`) and the password-recovery flow (all of `PasswordsController`). Those actions assert their signed-out rendering; every other action's signed-out context asserts the redirect to the login page. When an action's access changes, its paired contexts change with it.

Signing in is `sign_in_as(user)` from `AuthenticationHelper` in `spec/support/`, loaded by the support glob in `spec/rails_helper.rb`. It signs in over real HTTP, posting the user's credentials to `sessions#create`, so the session cookie the rest of the example relies on is the one production issues. It stubs nothing: `Current` is domain, and the Mocking discipline section below forbids stubbing it.

Authorization tests assert the negative space: forbidden access returns the redirect or 403/404, not just that allowed access works.

## What to assert

- **Observable outcomes, not method calls.** `have_received` tests means rather than ends; let the real code run and assert on what it did.
- **Essentials only.** If the response body is checked, `expect(response).to have_http_status(:ok)` next to it is redundant noise.
- **Hand-derived literals**, never expected values computed by the code under test - such a mirror assertion passes no matter what the code does.
- **Behavior, not constants**: "a failing call is retried 5 times", never `expect(MAX_RETRIES).to eq(5)`.
- **No `.first`/`.last`** (order-fragile); prefer `expect { … }.to change { Model.where(…).count }.by(1)`.
- **The mutation check** when reviewing: mentally break the production code (wrong branch, missing side effect, empty return) and name the example that catches it. A mutation nothing catches marks the behavior as unprotected, or the test as tautological.

## Mocking discipline

- **Mock only at boundaries**: external APIs, network, time, randomness. Never your own domain logic, ActiveRecord queries, or factories.
- **Never stub the system under test.**
- **Verified doubles only**: `instance_double`/`class_double`, so a typo fails the spec.
- **`travel_to`/`freeze_time`** for anything time-dependent; a time assertion without them is a red flag.
- External HTTP is blocked suite-wide: the `webmock` gem and `WebMock.disable_net_connect!` in `spec/rails_helper.rb` close the net as standing setup, not need-driven.

## Factories

- **Minimal factories**: only required fields with sensible defaults. No "just in case" attributes, no factories-as-fixtures like `create(:admin_user_with_premium_subscription)`; variation comes from traits, uniqueness from sequences, and associations are declared sparingly because they cascade record creation.
- **`build`/`build_stubbed` over `create`** when the database is not the point.
- **Faker fills descriptive, unconstrained fields and the seeds**; anything a validation constrains or an assertion reads gets a sequence or a literal, because random data deciding a test's outcome makes failures unreproducible.
- Use the bare `FactoryBot::Syntax::Methods` forms: `create(:user)`, never `FactoryBot.create(:user)`.
- One factory per model, in `spec/factories/`.

## Style

- `describe '.class_method'` / `describe '#instance_method'`; contexts start with when/with/without; no "should" in descriptions.
- **Inline setup over `let`/`before`**: the preconditions of an example are visible in its body. Reach for `let` only when three or more examples share the exact same object; over-use of `let`/`subject`/`before` is DRY taken too far in tests.
- `described_class` stays: it is the `rubocop-rspec` default and fighting the linter costs more than it buys.
- Arrange-Act-Assert visible in every example; specs are flat and static, no loops or clever helpers; concrete examples over abstractions.
- Nested contexts at most three deep, matching the `RSpec/NestedGroups` default; a genuinely necessary fourth level is a conversation with the owner, never an inline `rubocop:disable`. Never test private methods; test through the public one or make it public.
- One *behavior* per example. Several expectations are fine when they assert facets of that one behavior - a request spec checking the response and its side effect - and a second behavior gets its own example. `RSpec/MultipleExpectations` stands at `Max: 4` in `.rubocop.yml`, raised from the default `Max: 1` because a request spec asserting a redirect and the side effect that earned it is one behavior in two expectations. An example that genuinely needs a fifth facet either splits, or the ceiling itself is a conversation with the owner.

## Determinism

- **No `sleep`, ever.** Explicit waits. In Capybara: semantic selectors first (`:label`, `:button`, `:link`, `:field`) and never OR-chained `has_css?` calls - seed rules for #79's system specs, recorded early so that work is reviewed against them, the same reason this file predates #149.
- **No test interdependencies**: the suite passes under any order.
- Cover the edges deliberately: nil, empty collections, boundaries.
- Keep the output clean: a suite where anything new is immediately visible. When silencing noise, the fix may change how a test runs, never what it covers.

## Red flags

Over-mocking internal code; duplicate assertions across layers; unit tests for one-line delegations; mock setup longer than the test; setup hidden away from the example that depends on it (Mystery Guest); a test that fails on every intentional change but never on breakage; hand-rolled HTML strings where production renderers would stay in sync automatically.

