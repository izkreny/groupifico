> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add a member switcher to the styleguide (#361)

## The page under real policies

`StyleguidesController#allowed_to?` goes, so every partial on the page asks the signed-in user's own policies, as it does everywhere else. `show` keeps its `skip_verify_authorized`, because opening the page is still no decision: any signed-in developer may open it, and what it draws is decided per control by the partials' `allowed_to?`, which never satisfies `verify_authorized` anyway. Its comment says "draws seeded sample data for whoever opens it", which this branch makes false, so it is rewritten, and so is the sentence in `.agents/rails-style.md` that gives the same reason for the same skip.

`pick_members` keeps its one ordered, preloaded read of the group's members and hands it to the page as `@members`, which the switcher lists; a second read would raise on `roles` under strict loading.

## The switcher

A header at the top of `app/views/styleguides/show.html.erb`, `sticky top-0` on the root theme rather than inside either twin, saying who is signed in and holding a form: a labelled `select` of `@members`, each option the member's full name, their role tags' wording and their status, with the signed-in user's member selected, and a Switch button. `AppFormBuilder#field` reads `object.errors`, so this modelless form uses the builder's plain `label` and `select`. No JavaScript: a native select and a submit.

## The switch

A resource rather than a verb: `POST /styleguide/session`, nested as `resource :session, only: :create` under `resource :styleguide` with `scope module: :styleguides`, inside the existing `if Rails.env.local?` in `config/routes.rb`. `Styleguides::SessionsController#create` finds the member by `params.expect(:member_id)`, authorizes it, ends the current session with `terminate_session`, starts one for the member's user with `start_new_session_for`, and redirects to `styleguide_path`. A signed-out visitor never reaches it: `require_authentication` redirects to sign-in.

Outside development and test the action raises `ActionController::RoutingError`, what an absent route raises, so it answers the same 404 page. It is a `prepend_before_action`, so the 404 comes before the sign-in redirect and a production request learns nothing either way.

## Authorization

`Styleguides::SessionPolicy`, applied with `authorize! member, with: Styleguides::SessionPolicy` since the record is a `Member` whose own policy answers a different question. It skips both membership pre-checks, as `AddressPolicy` does, because the developer switching is rarely a member of the styleguide group, and `create?` grants only a member of the group `StyleguidesController::GROUP_NAME` names. That is its real deny case: the switch signs in as a user by id, and the rule keeps it to the seeded sample members rather than every account in the database. `docs/AUTHORIZATION.md` records it under `## Records that have no group at all`, whose opening count of "two things" becomes a sentence that survives a third.

## Specs that leaned on the override

The roster-controls example in `spec/requests/styleguides_spec.rb`, the daisyUI-class example beside it and the two RSVP-pill paint examples in `spec/styleguide/styleguide_spec.rb` all need a member whose policies permit those controls, so they sign in as the planted owner. `spec/support/styleguide_helper.rb` gains `planted_member(full_name)`, finding the planted member through its user's profile, so no example reaches for `.first` or a has-many row. The roster example's comment inverts, and a new example signs in as a user outside the group and finds none of the roster's controls. The comment atop `spec/requests/styleguides_spec.rb` saying no spec runs as production becomes false and is rewritten.

## Proving production has neither route

A `describe "its routes"` in `spec/requests/styleguides_spec.rb`, following the template example's precedent of a non-request check in the styleguide's own file: `Rails.env` answers production and `Rails.application.routes` a fresh `ActionDispatch::Routing::RouteSet`, `config/routes.rb` is loaded into it, and `recognize_path` refuses `GET /styleguide` and `POST /styleguide/session`. Both stubs are framework boundaries and reset with the example, so the live route set is never redrawn.

## Seen red

- The production-routes example for `/styleguide` passes before any change, since the guard exists: dropping the `if` from `config/routes.rb` turns it red.
- The production-routes example for the switch passes before the route exists: drawing the switch route outside the `if` turns it red.
- The switch's 404 example passes while the controller does not exist: removing the guard from the finished controller turns it red.
- The policy's `failed` example passes against an empty policy, which denies by default: `create?` returning true turns it red.
- The signed-out example fails until the controller exists, and afterwards `allow_unauthenticated_access only: :create` on the controller turns it red.
- The non-member example finding no roster controls fails while the override stands.
- The switcher, sticky-header and browser switch examples fail before the header exists; dropping `sticky` turns the scroll example red.

## Steps

- Write `spec/policies/styleguides/session_policy_spec.rb` (new) and `app/policies/styleguides/session_policy.rb` (new), watching each rule's examples fail as listed above.
- Write `spec/requests/styleguides/sessions_spec.rb` (new) for the switch, its refusal of another group's member, its 404 outside development and test, and the signed-out redirect, then route `config/routes.rb` and add `app/controllers/styleguides/sessions_controller.rb` (new).
- Add the production-routes examples to `spec/requests/styleguides_spec.rb` and watch each go red under its mutation.
- Add `planted_member` to `spec/support/styleguide_helper.rb` and sign the override-dependent examples in as the planted owner, all still green with the override in place.
- Add the non-member roster example, watch it fail, then remove `StyleguidesController#allowed_to?` and rewrite the skip comment and `.agents/rails-style.md`.
- Add the switcher examples to `spec/requests/styleguides_spec.rb` and the sticky-header and browser switch examples to `spec/styleguide/styleguide_spec.rb`, watch them fail, then expose `@members` and draw the header in `app/views/styleguides/show.html.erb`.
- Record the policy in `docs/AUTHORIZATION.md`.
- Run `bin/rspec spec/styleguide` and `bin/ci`.

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-12_GHI-361_styleguide-member-switcher.md`
- `bin/rspec spec/policies/styleguides spec/requests/styleguides spec/requests/styleguides_spec.rb` passes, each new example having been seen red as `## Seen red` lists
- `bin/rspec spec/styleguide` passes, its accessibility audit included
- `bin/ci` is green

No gate scrolls the seeded group's page, so how the fixed header sits over 44 roster rows and the long sections under both themes is the owner's to judge by opening `/styleguide` on a seeded development database and switching between members.

## Open questions

- How does the switch pass `verify_authorized`? 1. `Styleguides::SessionPolicy`, granting only a member of the styleguide group, which this plan builds since it needs no new skip. 2. A permanent `skip_verify_authorized only: %i[ create ]` on `Styleguides::SessionsController`, the environment and the sign-in being the whole gate, which is a new skip and so the owner's call per `.agents/rails-style.md`.
