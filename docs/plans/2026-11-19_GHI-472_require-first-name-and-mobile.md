> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: require a first name and mobile phone (#472)

## Approach

`UserProfile` gains `validates :first_name, :mobile_phone, presence: true, on: :setup` and a `setup?` predicate that asks plain presence of both columns, never `valid?(:setup)`, which would run the mobile's uniqueness query and fill `errors` on every request the gate makes. The empty profile `User` builds on create stays valid in the default context, so an email-only invitation, a sign-up and a join still save.

A new controller concern, `app/controllers/concerns/profile_setup.rb` (new), included by `ApplicationController` after `Authentication`, adds `before_action :require_profile_setup`: when `authenticated?` and the user's profile is not `setup?`, it redirects to `edit_user_profile_path` with an `info:` flash, `status: :see_other`. It asks `authenticated?` rather than `Current.user`, because on an `allow_unauthenticated_access` action such as the join page nothing has resumed the session yet. `allow_unset_profile only: …` skips it, mirroring `allow_unauthenticated_access`, and is declared on `UserProfilesController` (edit, update), `SessionsController#destroy` (sign out, AC2), `UsersController#destroy` and `PicksController`.

`UserProfilesController#update` becomes `assign_attributes` then `save(context: :setup)`, since `update` takes no context, and `Member::Import` checks `profile.valid?(:setup)` and saves with `save(context: :setup)`, so a refused row reaches the rake task's existing "line N: refused: …" output with both messages.

The `user` factory builds a set-up profile by default, because about nine hundred `sign_in_as` calls sign in a bare `create(:user)` that the gate would otherwise redirect; a `:not_set_up` trait keeps the empty profile for the specs that need it.

## Decisions taken under the `auto` chain

Each is the owner's to overturn on the PR.

- `UsersController#destroy` is exempt from the gate, so the profile form's "Delete my account" stays a working control for a user who has not set up, rather than a form certain to be refused.
- The gate carries `return_to` on a GET, and `UserProfilesController#update` redirects to `return_to || root_path` through the existing `Authentication#return_to`, with the form posting it as a hidden field. Without it a visitor who signs in through a group's join link saves the profile and lands on the groups list instead of the join page they came from, which regresses #446 and #447.
- `PicksController` is exempt, because the development element picker posts from every page, the profile form included.
- The import validates the profile after `fill_blanks`, as N1 states, so a row with a blank mobile for an existing user whose profile already holds one is imported, and a row for someone already a member is untouched as today.
- The mobile field's hint drops "Optional.", and the last name gains the hint "Optional.", so the form says which field may stay empty.

## Steps

- ::S1:: In `spec/factories/user_profiles.rb`, turn the `:with_all_attributes` mobile into a global `sequence(:mobile_phone)`; in `spec/factories/users.rb`, add a transient `set_up { true }` and an `after(:build)` that builds the profile with the transient `first_name` and `generate(:mobile_phone)` when set, plus a `:not_set_up` trait setting it false; move every existing spec that reads an empty profile, such as the already-member example in `spec/models/member/import_spec.rb` and the name fallbacks, onto `:not_set_up`; the suite stays green, behaviour unchanged
- ::S2:: In `app/models/user_profile.rb`, add the `on: :setup` presence rule and `setup?`; in `spec/models/user_profile_spec.rb`, cover the presence rule on `:setup`, the empty profile valid in the default context, `setup?` both ways, and the last name optional on `:setup` (AC3, AC5)
- ::S3:: In `app/models/member/import.rb`, validate and save the profile in the `:setup` context; in `spec/models/member/import_spec.rb`, add examples refusing a new row without a first name and one without a mobile, each naming line 2 and the field, and one importing an existing set-up user's row whose mobile is blank (AC4)
- ::S4:: In `app/controllers/user_profiles_controller.rb`, save in the `:setup` context and redirect to `return_to || root_path`; in `app/views/user_profiles/_form.html.erb`, carry `return_to` as a hidden field and change the two hints; in `spec/requests/user_profiles_spec.rb`, add examples refusing a save without a first name and without a mobile with each field's error in the body, accepting one without a last name, and following `return_to` (AC3, AC5)
- ::S5:: Add `app/controllers/concerns/profile_setup.rb` (new), include it in `app/controllers/application_controller.rb`, and declare `allow_unset_profile` on the four controllers; add `spec/requests/profile_setup_spec.rb` (new) covering a not-set-up user redirected from the groups list, a group page, a non-GET and the join page, carrying `return_to` on the GETs, a set-up user passing through, the profile form rendering, and in `spec/requests/sessions_spec.rb` signing out while not set up (AC1, AC2)
- ::S6:: In `spec/system/me_spec.rb`, add an example signing in a not-set-up user, visiting the groups list, landing on the profile form with the info flash painting and no accessibility violations, filling the first name and mobile, saving and reaching the groups list (AC1)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-19_GHI-472_require-first-name-and-mobile.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-19_GHI-472_require-first-name-and-mobile.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/user_profile_spec.rb` passes; the AC3 examples are seen failing against `main`'s model, and the AC5 example against the branch's model with `:last_name` added to the presence rule
- ::V4:: `mise exec -- bin/rspec spec/models/member/import_spec.rb spec/tasks/members_import_spec.rb` passes; the AC4 examples are seen failing against `main`'s `Member::Import`
- ::V5:: `mise exec -- bin/rspec spec/requests/user_profiles_spec.rb spec/requests/profile_setup_spec.rb spec/requests/sessions_spec.rb` passes; the AC1 and AC3 examples are seen failing against `main`'s code, the AC2 example against the branch with `SessionsController`'s `allow_unset_profile` removed, and the AC5 example against the branch with `:last_name` added to the presence rule
- ::V6:: `mise exec -- bin/rspec spec/system/me_spec.rb` passes; the AC1 example is seen failing against the branch with `ProfileSetup` left out of `ApplicationController`
- ::V7:: `mise exec -- bin/rspec spec/requests/styleguides_spec.rb spec/styleguide` passes, since the styleguide draws the profile form and `bin/ci` never runs `spec/styleguide`
- ::V8:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V9:: `mise exec -- bin/ci` passes, browser suite included

The specs prove the gate, the refusals and the import; whether the info flash's wording reads well to a member who just followed an invitation, and whether every existing member without a mobile being sent to the form at their next sign-in is acceptable on production data, is the owner's to judge.

## Open questions

None.

## Settled

- Should the last name stay optional, as the issue first had it? No: after the first review pass the owner required it like the first name and the mobile, in the form, the import and the gate, so a member without one is sent to the form too, and the last name's "Optional." hint goes.
