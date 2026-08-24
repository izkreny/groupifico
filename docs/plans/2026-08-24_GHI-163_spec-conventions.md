> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: write the spec conventions (#163)

The spec suite #149 will build needs its rules written down first, so that suite is reviewed against agreed conventions instead of establishing them mid-diff. The deliverable is one new file, `.agents/testing.md`, plus a pointer to it from the agent instructions' testing section. Everything below sketches what the file records, so this PR's review argues with the conventions themselves rather than with the idea of writing them.

## Proposal: the shape of `.agents/testing.md`

The file sits beside `.agents/github.md` and follows its shape: per-repo facts an agent should look up rather than assume, opening with what the file is and that it wins on conflict within its subject. Its sections:

- **Framework choices.** RSpec (`rspec-rails ~> 8.0`) with FactoryBot (`factory_bot_rails`), plus `capybara` and `selenium-webdriver` waiting in the Gemfile for the system layer. Recorded as this repository's deliberate choice against the 37signals default of minitest with fixtures, so no future alignment pass "fixes" it: per #163, testing is where this repository keeps its own choices.
- **Spec layers and what each covers.** Model specs for validations, associations and model logic, the one layer that exists today, covering all seven models. Request specs for controller behaviour, one file per controller, every action covered, arriving with #149. Helper specs for helpers that carry logic. No controller or view specs: request specs are the one layer that covers controllers. System specs appear only as a boundary line: the system layer, its CI job and its first specs belong to #79, and this file defines no system-spec conventions until that work lands.
- **The signed-in/signed-out pairing pattern.** Every controller action is asserted in two contexts, signed in and not signed in, the latter asserting the redirect to the login page. The signed-out surface is deliberately tiny, the login page and the create-group-user page being the only pages a signed-out visitor sees, so every other action's signed-out context asserts the redirect; those two assert their signed-out rendering instead. When authorization lands this rule gets revisited and updated if needed. Signing in is `sign_in_as(user)` from `AuthenticationHelper` in `spec/support/`, auto-loaded by the support glob in `spec/rails_helper.rb`; the helper and the seed example, the salvage branch's `spec/requests/user_spec.rb`, land via #149, whose body quotes the helper. The convention is stated as a rule even though the code lands later, because that is the point: #149 gets reviewed against this file.
- **Factories.** One factory per model in `spec/factories/`, used through `FactoryBot::Syntax::Methods`, so `create(:user)` and never `FactoryBot.create(:user)`.
- **The local gate.** `bin/ci`, named here and owned in detail by `.agents/github.md`: a pointer, not a second copy.

## Proposal: the pointer from the agent instructions

`AGENTS.md`'s `### TESTING` section keeps its one-line framework summary and gains a line pointing at `.agents/testing.md` for the conventions, mirroring how the section already points at `.agents/github.md` for the gate. `CLAUDE.md` and `GEMINI.md` are symlinks to `AGENTS.md`, so one edit covers all three.

## Steps

- Write `.agents/testing.md` with the sections proposed above
- Edit the `### TESTING` section of `AGENTS.md` to point at `.agents/testing.md`

## Verification

- `bin/ci` passes, the repository's one local gate; a docs-only diff gives it little to catch, so a green run proves nothing broke rather than that the conventions are right
- [owner] Read `.agents/testing.md` against #163's acceptance criteria: framework choices, spec layers, the pairing pattern and the local gate are recorded, the #79 boundary line is present, and the agent instructions point at the file

What the gate cannot see: whether these are the conventions the owner wants #149 reviewed against. The file's whole content is judgement, and this PR's review is where that judgement happens.

## Open questions

- Should `.agents/testing.md` quote the `AuthenticationHelper` code, or only name the pattern and point at #149? Recommendation: prose only. The code is already preserved in #149's body, and a quoted copy here starts drifting the day the helper changes shape during the salvage.
- Should the "no controller or view specs" line be an explicit ban or just an omission? Recommendation: an explicit line. The point of the file is that a future spec author does not pick a layer nobody agreed on, and silence does not carry that.
