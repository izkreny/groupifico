> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: audit policies for mechanism defects (#195)

## Approach

The audit is a read first and a diff second. Every criterion on #195 was checked against the code before this plan was written, and most of them already pass: the fix set below is what is left after that pass, and the closing comment is where the passing ones get recorded so the audit is a fact rather than a claim.

What the read found, criterion by criterion:

- **Authorization coverage** holds. Every action in `app/controllers/addresses_controller.rb`, `app/controllers/events_controller.rb`, `app/controllers/groups_controller.rb`, `app/controllers/members_controller.rb`, `app/controllers/registrations_controller.rb` and `app/controllers/user_profiles_controller.rb` calls `authorize!`. The three skips are `app/controllers/sessions_controller.rb`, `app/controllers/passwords_controller.rb` and `app/controllers/users_controller.rb`, and only the last is stale.
- **Index scoping** holds, in all five collection actions, and `verify_authorized_scoped if: -> { action_name == "index" }` in `app/controllers/application_controller.rb` enforces it rather than trusting it.
- **No policy is constructed directly.** `grep` over `app/` finds no `Policy.new`; the only `Policy` mentions outside `app/policies/` are the two `rescue_from` lines and comments.
- **Every declared alias is proven** with `be_an_alias_of`: `edit?` in `spec/policies/address_policy_spec.rb`, `edit?` and `update?` in `spec/policies/user_profile_policy_spec.rb`.
- **Every scope spec names `type: :active_record_relation`**, in all six policy specs.

So the diff is three defects, all in the same family: a rule or a skip that says something the mechanism no longer supports.

**The stale skip.** `app/controllers/users_controller.rb` carries `# TODO(#172): remove this skip when UserPolicy lands.` #172 is closed and `UserPolicy` was never written, so the comment promises a policy nobody is writing. Which way it resolves is recorded under `## Settled`.

**The unproven rules.** `GroupPolicy` defines `index?`, `new?` and `create?` and `spec/policies/group_policy_spec.rb` has no `describe_rule` at all; `AddressPolicy#index?` returns true and `spec/policies/address_policy_spec.rb` never asks it. Action Policy's `Defaults` module answers `index?` and `create?` false, so each of these four is an override that grants access, and a rule that grants access with nothing asserting it is exactly the deny-by-default trap #195 names: delete the override and the call lands back on that false, which reads as a considered refusal and is not one.

**The shadowed alias.** `def new? = true` in `app/policies/group_policy.rb` is a real method, and Action Policy drops the inherited `new? -> create?` alias the moment one exists. It buys nothing: with the method gone and `new?` dropped from the `skip_pre_check` list, `resolve_rule` follows the alias, `result.rule` arrives as `:create?`, the skip still matches and the verdict is identical. What it costs is the lockstep `app/policies/application_policy.rb` explicitly relies on, whose own comment says `new?` is absent from `WRITE_RULES` only because the alias keeps it pinned to `create?`. Two of this repository's policy specs already carry a comment saying alias-shadowing has been caught twice; this is the third.

## Deliberately out of scope

Who may do what. `docs/AUTHORIZATION.md` owns the capabilities and #96 and #173 write the role rules; nothing here changes a verdict for any user.

Two things #195 asks the audit to record rather than refile, both confirmed on the read:

- `ApplicationPolicy` has no policy spec of its own, and needs none. Its `paused` and `inactive` branches are exercised across the request specs, and `.agents/testing.md` forbids duplicating one behavior assertion at two layers.
- `EventPolicy`, `MemberPolicy` and `RegistrationPolicy` define no rules at all, only `group_for` and a scope. Their verdicts are `ApplicationPolicy`'s, so the bullet above covers them and their scope specs are complete as they stand.

One correction to the issue's own text, which the closing comment repeats. #195 says `UsersController` has no request spec, looking for one under a plural filename. There is one, `spec/requests/user_spec.rb`, named after the singular `resource :user` route, and it covers the controller action by action. The testing-conventions question dissolves into a naming observation and needs no separate decision.

## Steps

- Restate the skip in `app/controllers/users_controller.rb` as permanent by design, naming its own actions, and delete the `TODO(#172)` line
- Scope the skip in `app/controllers/passwords_controller.rb` with `only:` naming its own actions, for the reason `app/controllers/sessions_controller.rb` already states: an unscoped skip hands a future action an exemption nobody chose for it
- Remove `def new? = true` from `app/policies/group_policy.rb` and drop `new?` from its `skip_pre_check` list, restoring the inherited `new? -> create?` alias
- Add `describe_rule :index?` and `describe_rule :create?` to `spec/policies/group_policy_spec.rb`, each asserting the permitted case for a signed-in user with no membership, since that is the state the skipped pre-checks exist for
- Add the restored alias to the same spec as `expect(:new?).to be_an_alias_of(policy, :create?)`, which fails on the current code and passes once the method is gone
- Add `describe_rule :index?` to `spec/policies/address_policy_spec.rb`, succeed-only, with a line saying no denial case is constructible for a rule that is unconditionally true
- Draft the closing comment for #195: every criterion with its result, the four that already passed named as passing, and the correction above

## Verification

- `bin/ci` passes on this branch
- The suite's docs check passes over `docs/plans/2026-08-30_GHI-195_audit-policy-mechanism.md`
- `bin/rspec spec/policies` passes with the new examples, and the alias example is watched failing on the pre-fix `app/policies/group_policy.rb` before the method is removed
- `git diff main -- app/policies app/controllers` shows no change to any rule body other than the removed `new?`, which is what "no verdict moves" means concretely

The suite is the gate for the code and it cannot gate the audit. Nothing in `bin/ci` knows whether a criterion was checked honestly or whether the closing comment tells the truth about what was found, so the record is the deliverable and reading it is the only check on it. The alias example is the one place a green suite would otherwise prove nothing, which is why it is watched failing rather than trusted for passing.

## Open questions

None.

## Settled

- **How does the `UsersController` skip resolve?** Permanent by design, restated as `skip_verify_authorized only: %i[ show new edit create update destroy ]` with a comment splitting the two reasons. `show`, `edit`, `update` and `destroy` all run through `set_user`, which returns `Current.user`, so the record is named by the caller's own signed cookie and never by the request: one possible input, one possible answer, which is the argument `app/controllers/sessions_controller.rb` already makes for its own `destroy`. `new` and `create` do carry a question, but it is whether a signed-in user may create a second user at all, which is a product question rather than an authorization one, so no rule this issue could write would answer it. The rejected alternative was a `UserPolicy` issue under #153, keeping the skip temporary and pointed at something open; it costs a policy with one rule that nothing currently needs. Settled in the terminal, 2026-08-30.
