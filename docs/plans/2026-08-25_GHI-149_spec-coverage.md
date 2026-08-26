> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: cover the existing code with specs (#149)

`main` has model specs and factories and nothing above them, so every controller, route, view and helper is unverified. This plan covers the gap the issue names, against the rules `.agents/testing.md` set in #163.

**Two commits are already on this branch**, landed before the plan at the owner's direction so the plan would describe reality rather than the salvage source. `5244426` moves all three files of the `add_integration_specs` branch across verbatim and raises `RSpec/MultipleExpectations` to `Max: 4`. `bb7e9ee` reworks what arrived: `sign_in_as` now posts real credentials to `sessions#create` instead of stubbing `Current`, the missing comma in `post user_path params:` is fixed at four sites, two misnamed examples are corrected, and both `let!` pairs become inline setup. Everything below is what remains.

## The surface to cover

Nine controllers, 52 public actions. `UsersController` is done, so 46 remain, each in a signed-in and a signed-out context.

| Controller | Actions | Count |
|---|---|---|
| `users` | show new edit create update destroy | 6, done |
| `sessions` | new create destroy | 3 |
| `passwords` | new create edit update | 4 |
| `user_profiles` | show edit update | 3 |
| `groups` | index show new edit create update destroy | 7 |
| `addresses` | index show new edit create update destroy | 7 |
| `members` | index show new edit create update destroy | 7 |
| `events` | index show new duplicate edit create update destroy | 8 |
| `registrations` | index show new edit create update destroy | 7 |

`user_profiles` has three actions rather than four because #168 removed its `destroy` and routed it out with `except: :destroy`.

The signed-out surface is `sessions#new`, `sessions#create` and all four of `PasswordsController`, the only actions declaring `allow_unauthenticated_access`. Those assert their signed-out rendering; every other action's signed-out context asserts the redirect to `new_session_path`.

The nested resources need a group for `members` and `events`, and a group plus an event for `registrations`. `events#duplicate` is a `GET` on a member route and gets the same pair as the rest.

**No HTML assertions anywhere in this suite.** The front end is due a large change, so any assertion against rendered markup would be written to be deleted. Each example asserts the response status, the redirect, or the record and count the action changed, and never the page. This matches what the Basecamp apps do in the reference clones: `boards_controller_test.rb` checks `assert_difference` and the created record's own attribute rather than scraping the page for it, and reaches for `assert_select` only where a view branches on permission. Ours are scaffold views with no conditionals, so nothing here earns it.

**No system specs either.** The system layer, its CI job and its first specs belong to #79, and `.agents/testing.md` defines no system-spec conventions until that lands. This issue is the suite half: model, request and helper specs.

## Helper specs: two files, not eight

`.agents/testing.md` wants specs for helpers that carry logic and calls one-line delegations a red flag, which splits the eight helpers three ways.

- **Worth specs:** `EventsHelper#event_schedule`, which branches on `same_day?` and formats each side differently, and `RegistrationsHelper#members_available`, which is a set difference over two associations. `EventsHelper#event_statuses` comes along with the first file, since its `map` to upcased pairs is more than a delegation.
- **Not worth specs:** `MembersHelper#member_statuses` and `#member_roles`, `RegistrationsHelper#registration_statuses` and `EventsHelper#event_categories` are each one call to an enum's `keys`.
- **Nothing to spec:** `ApplicationHelper`, `AddressesHelper`, `GroupsHelper`, `UserProfilesHelper` and `UsersHelper` are empty modules.

## `Session`, WebMock, and the recombine

`Session` is the one model with neither spec nor factory, and every signed-in request spec creates one by posting to `sessions#create`. It gets `spec/models/session_spec.rb`; the model declares only `belongs_to :user`, so the spec is a `shoulda-matchers` one-liner. It gets **no factory**: because every signed-in example creates its session through the controller, nothing ever needed to build one directly, and the factory written here was deleted again during review.

`webmock` is not in the Gemfile. It joins the `:test` group with `WebMock.disable_net_connect!` in the suite setup, so the closed net becomes standing setup rather than need-driven. **This step needs the owner's live approval of the `bundle add` prompt**; naming it here does not authorise it.

The two `User` profile-invariant examples that #168 split to satisfy `Max: 1` recombine into one, which is what raising the cop to `Max: 4` was for.

`.agents/testing.md` has one remaining future-tense sentence, the WebMock bullet, and it moves to the present in the same change that makes it true. The sign-in helper line and the cop sentence were already corrected in `bb7e9ee`.

## Steps

- Add `webmock` to the Gemfile `:test` group and wire `WebMock.disable_net_connect!` into `spec/rails_helper.rb`
- Add `spec/models/session_spec.rb`
- Recombine the two `User` profile-invariant examples in `spec/models/user_spec.rb` into one
- Write request specs for the unauthenticated surface: `sessions` and `passwords`
- Write the request spec for `user_profiles`
- Write request specs for the top-level resources: `groups` and `addresses`
- Write request specs for the nested resources: `members`, `events` and `registrations`
- Write helper specs for `EventsHelper` and `RegistrationsHelper`
- Move the WebMock bullet in `.agents/testing.md` to the present tense

## Verification

- `bin/ci` passes, the repository's one local gate and a superset of the four CI jobs
- `bin/rspec` runs clean in a randomised order, so the suite carries no interdependencies
- [owner] The mutation check, per `.agents/testing.md`: for each new request spec, break the action it covers and confirm a named example goes red. This has no exit code and is the only evidence the specs would catch a regression
- [owner] Read the diff against #149's acceptance criteria on the issue

What the gates cannot see: `bin/ci` proves the specs pass, never that they would fail on a defect. A request spec asserting only `have_http_status :ok` passes on a view rendering the wrong record, and only the mutation check finds that.

## Open questions

None - all four settled during this PR's plan review.

## Settled

- Does the `profile` presence backstop keep its two stub-based examples? **Yes, folded into one example.** #168 settled the validation itself as a deliberate backstop, so it stays, and `allow(user).to receive(:build_profile)` is the only way to make a backstop fire. The example is named so the stub reads as deliberate rather than as an oversight.
- How much HTML should a request spec assert? **None at all.** The front end is due a large change, so markup assertions would be written to be deleted; examples assert status, redirect, and the record or count that changed.
- Does this land as one PR or several? **One PR.** Several PRs for one issue also fights the one-issue-per-branch convention, and `Closes #149` can sit on only one of them.
- Does this ticket cover system specs? **No.** They belong to #79 along with the `system-test` CI job.
