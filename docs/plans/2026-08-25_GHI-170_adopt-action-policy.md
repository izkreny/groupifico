> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: adopt action policy for authorization (#170)

Put a policy layer in the application and make a forgotten authorization check fail loudly, so the five group-scoped controllers have somewhere to hang their rules when #172 writes them. This branch deliberately does not write those rules. What it delivers is the mechanism, the fail-closed guard, and one pilot controller that proves the whole path end to end, because a mechanism with no consumer cannot be verified and an unverified guard is the thing this epic exists to stop trusting.

Every API fact below was read from Action Policy's own guide and source at 0.7.6 rather than recalled, and the surprising ones are called out where they land.

## Proposal: the gem and the generated base policy

`gem "action_policy"` in the main group, then `bin/rails generate action_policy:install`. The generator creates exactly one file, `app/policies/application_policy.rb`, and nothing else.

**Deny by default needs no code**, which is worth stating because the obvious instinct is to write it. `ActionPolicy::Base` includes `ActionPolicy::Policy::Defaults`, which runs `base.default_rule :manage?` and defines `manage?` returning `false`. A rule the policy does not define resolves to `manage?` and is denied. So an empty policy denies everything, and the first criterion on #170 is satisfied by the superclass rather than by us.

The one thing worth knowing about that mechanism: with the standard base class a missing rule does **not** raise `ActionPolicy::UnknownRule`, because the default rule always resolves first. Denial and "you forgot to write this rule" are therefore the same outcome, which is the safe direction but means a typo in a rule name reads as a denial. The `verify_authorized` guard below does not catch that; only a spec does.

## Proposal: the authorization context, because this application has no `current_user`

Action Policy's railtie does two things automatically, both defaulting to on:

```ruby
ActiveSupport.on_load(:action_controller) do
  next unless app.config.action_policy.auto_inject_into_controller
  ActionController::Base.include ActionPolicy::Controller

  next unless app.config.action_policy.controller_authorize_current_user
  ActionController::Base.authorize :user, through: :current_user
end
```

The second line is the trap. This application has no `current_user` method anywhere; the acting user is `Current.user`, reached through `Current.session`. Left alone, every `authorize!` would call a method that does not exist.

So `ApplicationController` overrides the context explicitly:

```ruby
authorize :user, through: -> { Current.user }
```

A proc rather than a method name, so nothing new is added to the controller's public surface just to satisfy the gem. `Current.user` already delegates through `Current.session` with `allow_nil: true`.

Both config flags stay at their defaults. In particular `auto_inject_into_controller` stays `true`, which is what keeps this application clear of `palkan/action_policy#312`, the Rails 8.1 initialization-order issue: that issue only reaches an application that turns the flag off from `config/initializers/`.

## Proposal: `verify_authorized`, with an explicit skip list that shrinks to zero

This is the fail-closed guard, and it is opt-in. Injecting the controller module does not enable it.

```ruby
class ApplicationController < ActionController::Base
  verify_authorized
end
```

`verify_authorized` registers an `after_action` that raises `ActionPolicy::UnauthorizedAction` when the action completed with `authorize_count.zero?`.

**Turning it on globally breaks every controller at once**, because none of them authorizes anything yet. The whole application, and the entire request-spec suite, would go red on the first commit. That is not a reason to weaken the guard; it is a reason to enable it with an explicit list of controllers that have not been converted:

```ruby
class GroupsController < ApplicationController
  # TODO(#172): remove this skip when GroupPolicy lands.
  skip_verify_authorized
end
```

One skip per unconverted controller, each naming #172, each removed by the commit that gives that controller a policy. The list is greppable, it is in the diff, and it reaches zero when #172 is done.

Two properties make this better than deferring the guard to #172 entirely. A controller added tomorrow inherits the guard and carries no skip, so it is protected by default rather than by somebody remembering. And the skip is visible in review, where a missing check is not.

`PasswordsController` and `SessionsController` need the skip permanently rather than provisionally, since both are unauthenticated by design. Their skips say so instead of naming #172.

## Proposal: one pilot controller, `UserProfilesController`

The guard cannot be trusted until it has been watched failing and watched passing, and neither is possible without one controller that actually authorizes.

`UserProfilesController` is the right pilot and the choice is deliberate. It is three actions. It already resolves from `Current.user` and ignores the params, so it is not part of the exposure #172 closes and converting it changes no behaviour. Its rule is the simplest true statement in the app: the profile is yours.

```ruby
class UserProfilePolicy < ApplicationPolicy
  def show?  = record.user_id == user.id
  def edit?  = show?
  def update? = show?
end
```

This is the one place this branch widens beyond "mechanism only", and it is the minimum that makes the branch verifiable rather than merely compilable.

## Proposal: the rescue, and what a failure returns

```ruby
rescue_from ActionPolicy::Unauthorized, with: :deny_access
```

`ActionPolicy::Unauthorized` carries `policy`, `rule` and `result`, and `result` is where the reasons live. For this branch `deny_access` renders `403`, and that is all it does.

**It is written so #172 can split the outcome without rewriting it.** Action Policy's own guide gives the shape:

```ruby
rescue_from ActionPolicy::Unauthorized do |ex|
  if ex.result.all_details[:not_found]
    head :not_found
  else
    head :unauthorized
  end
end
```

That `all_details` branch is exactly how #172 gets `404` for a non-member and `403` for a member with the wrong role, from one rescue, decided by the policy that denied rather than by the controller. This branch does not build it, because nothing yet produces a `not_found` detail, but the rescue is placed where that arrives.

`403` here is distinct from what `Authentication` already does, which is redirect an unauthenticated request to sign-in. Those are different answers to different questions and this is the first time the application can tell them apart.

**A Rails behaviour this rests on, to be verified rather than assumed:** when a `before_action` halts the chain, `after_action` callbacks do not run, so `require_authentication` redirecting an unauthenticated request should never trip `verify_authorized`. #149's "when not signed in" examples cover exactly that case and will say so.

## Proposal: spec support

Two requires in `spec/rails_helper.rb`:

```ruby
require "action_policy/rspec"
require "action_policy/rspec/dsl"
```

The first supplies `be_authorized_to`, `have_authorized_scope` and `be_an_alias_of`. The second supplies the `describe_rule` / `succeed` / `failed` DSL, which is auto-included only for examples tagged `type: :policy` or living in `spec/policies`, so policy specs go in `spec/policies/` and need no tag.

The conventions in `.agents/testing.md` govern how those specs are written; nothing here overrides them.

## Proposal: the two documents that record the decision

`.agents/rails-style.md` currently reads "Decided 2026-08-24: authorization goes through Pundit policy objects... The gem is not in the Gemfile yet". Both halves stop being true on this branch. The entry is rewritten to record Action Policy as landed, so a reviewer working from the Rails style baseline does not read `app/policies/` as a violation.

`docs/adr/2026-08-25_authorization-with-action-policy_0003.md` is written in full: the survey evidence, the gems measured, why a policy layer at all against the house model-predicate default, why Action Policy over Pundit, why not CanCanCan, and the reversibility asymmetry accepted. It follows the shape of `0001` and `0002`.

## Steps

- Add `gem "action_policy"` and run `bin/rails generate action_policy:install`
- Override the authorization context in `ApplicationController` with `authorize :user, through: -> { Current.user }`
- Enable `verify_authorized` in `ApplicationController`, and add a `skip_verify_authorized` to every controller that does not yet authorize, each naming #172 except the two unauthenticated ones
- Add `rescue_from ActionPolicy::Unauthorized`, rendering `403`, shaped so #172 can branch on `result.all_details`
- Convert `UserProfilesController` as the pilot: `UserProfilePolicy`, `authorize!` in the actions, and no skip
- Require `action_policy/rspec` and `action_policy/rspec/dsl` in `spec/rails_helper.rb`
- Add `spec/policies/user_profile_policy_spec.rb` covering a permitted and a denied rule
- Add a request spec proving `verify_authorized` raises for an action that authorizes nothing
- Rewrite the authorization entry in `.agents/rails-style.md`
- Write `docs/adr/2026-08-25_authorization-with-action-policy_0003.md`

## Verification

- The guard is watched failing: `skip_verify_authorized` is temporarily removed from one unconverted controller, a request to it raises `ActionPolicy::UnauthorizedAction`, and the skip is put back. A guard never seen to fail is not evidence, and this one exists solely to catch an omission nobody made on purpose
- The pilot is watched failing in both directions: `UserProfilePolicy#show?` is temporarily inverted and the policy spec goes red, then restored; and a request for another user's profile is refused while the owner's own succeeds
- The deny-by-default claim is watched rather than trusted: a policy with no `destroy?` rule refuses `destroy?`, proving the fall-through to `manage?` denies rather than errors
- An unauthenticated request to a converted action still redirects to sign-in and does **not** raise `UnauthorizedAction`, proving the halted `before_action` chain skips the `after_action`
- `bin/rubocop` passes, including on `app/policies/`
- `bin/ci` passes on the final tree
- [owner] Read ADR 0003, particularly the section conceding that Pundit was the more reversible choice and was not taken. That is the paragraph a future reader will weigh this decision by
- [owner] Read the rewritten `.agents/rails-style.md` entry, since it is what tells every future agent session that `app/policies/` is intended rather than a violation

What these gates cannot see: whether the skip list actually shrinks. Every gate here passes just as well with all five skips still in place, because a skipped controller is a controller that authorizes nothing and raises nothing. Only #172 landing removes them, and only a human reading the diff notices if it does not.

## Open questions

- **Does this branch wait for #171 (#149, spec coverage) to merge?** That branch adds `spec/support/authentication_helper.rb`, `sign_in_as`, and request specs for all five group-scoped controllers, and it edits `spec/rails_helper.rb`, which this branch also edits. Writing a second request-spec harness here would duplicate it and then have to be reconciled. The plan above assumes #171 lands first and this branch uses `sign_in_as`. If that assumption is wrong, the request-spec step needs its own harness and this plan grows.
- **Should `verify_authorized_scoped` be enabled too?** Action Policy ships a second guard, raising `ActionPolicy::UnscopedAction` when an action completes without `authorized_scope`. It is the guard that would catch an `index` leaking another group's records, which is a real criterion on #172. It is left off here because nothing scopes yet and it would need its own skip list, but it may belong in #172 rather than never.
- **Does the pilot belong on this branch at all?** The alternative is a mechanism-only branch whose verification is a policy spec with no controller behind it. That keeps #170 to its stated scope but leaves the guard unproven against a real request until #172.

## Settled

None yet.
