> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Restrict group data to its members

Implementation plan for [#172](https://github.com/izkreny/groupifico/issues/172). The acceptance criteria live on the issue; this file answers *how*.

## What is actually broken

Read from the code on `main` at `a6a549e`, not recalled.

Four controllers root at the same unscoped lookup, and the nesting means the root is the whole hole. `GroupsController#set_group` and `EventsController#set_group`, `MembersController#set_group` and `RegistrationsController#set_group` all call `Group.find(params.expect(:group_id))` or its `:id` twin. Everything below that is already scoped through the association - `@group.events.find`, `@group.members.find`, `@event.registrations.find` - so a member record cannot be reached from the wrong group. Only the group itself is reachable by anybody who types its id.

`root "groups#index"` renders `Group.all`, so the application's landing page lists every group in the database to every signed-in user.

`AddressesController` is the exception: #170 converted it, and it authorizes through `AddressPolicy` already. What it still lacks is a scoped `index`, which is why its skip is narrowed to `index`, `new` and `create` rather than removed.

## Two holes the issue's criteria do not currently name

Both are strong-parameter holes rather than lookup holes, so scoping the lookup does not close either. Raised here rather than fixed silently; see `## Open questions`.

**Every nested controller permits the foreign key that decides where its record lives.** `member_params` and `event_params` permit `:group_id` outright. `registration_params` permits `:event_id` and `:member_id` instead, which is the same defect one level down, since the event is what carries the group. A legitimate member of group A can therefore move a record into group B by posting that key, which is the boundary-crossing this issue exists to close, arriving through the body instead of the URL.

The key is redundant as well as dangerous. `create` already derives it from the association - `@group.members.new(member_params)`, `@group.events.new(event_params)`, `@event.registrations.new(registration_params)` - so on create the permitted key can only ever contradict the URL, and on `update` it is the only thing that can move the record at all.

**`MembersController` permits `:role` and `:user_id`.** The issue's criterion covers the non-member case - *"refused for a user who does not already belong to the group"* - and stops there. It does not cover a user who does belong: today an ordinary member can `PATCH` their own membership to `role: :owner`, or create a membership for somebody else. Half of that is genuinely #93 and #96, which decide what a role is. The other half, `user_id`, is not about roles at all.

## Approach

**Belonging and status are asked once, on `ApplicationPolicy`, not per policy.** Both questions are the same for every record in a group, and Action Policy's `pre_check` is built for exactly this: declared once on the base class, run before every rule. Repeating them per policy is how the next policy added to the app quietly rejoins the set of unprotected ones.

**Each policy answers only "which group is this record in".** `GroupPolicy` answers with the record, `EventPolicy` and `MemberPolicy` with `record.group`, `RegistrationPolicy` with `record.event.group`. That one hook is the entire per-policy surface for this issue; the rules themselves stay empty until #93 and #96 give them roles to consult.

**`AddressPolicy` keeps its own answer and is not moved onto the pre-checks.** An address has no group of its own; it is reachable through whichever group or event points at it, and #170 already wrote that. Forcing it through a `group_for` hook would mean inventing a single group for a record that can belong to several.

**The refusal is one handler that branches on the denial's reason, never a conditional per controller.** A policy that denies for non-membership calls `deny!(:not_found)`; `ApplicationController#deny_access` reads `ex.result.all_details` and renders `404` for that detail and a redirect carrying an alert for everything else. Two answers to two different questions: the record does not exist for you, versus you may not do this to it.

**`404` for a non-member is deliberate**, per ADR 0003 and the Basecamp idiom: a `403` confirms that a given id exists, which is precisely what a non-member should not learn.

**`index` is scoped with `authorized_scope`, and `verify_authorized_scoped only: :index` is what makes forgetting it fail.** Enabled bare it fires on `show`, `edit`, `update` and `destroy`, which scope nothing, so it is constrained to the one action where returning a collection unscoped is the leak.

## Steps

- Add `pre_check :verify_membership!` and `pre_check :verify_active_membership!` to `ApplicationPolicy`, with a `group_for` hook that each policy overrides, and no default that guesses
- Have the membership pre-check `deny!(:not_found)` rather than plain `deny!`, so the reason survives to the rescue handler
- Write `GroupPolicy`, `EventPolicy`, `MemberPolicy` and `RegistrationPolicy`, each supplying `group_for` and nothing else until roles land
- Give `GroupPolicy` a `relation_scope` returning the acting user's groups, and use it from `GroupsController#index`
- Give `EventPolicy`, `MemberPolicy` and `RegistrationPolicy` their own `relation_scope`s, so an `index` nested under an authorized group is still scoped rather than trusting the nesting
- Add `authorize!` to every action in `GroupsController`, `EventsController`, `MembersController` and `RegistrationsController`, including the non-REST `EventsController#duplicate`, which the route exposes as a member action and which is as capable of leaking as `show`
- Replace `head :forbidden` in `ApplicationController#deny_access` with a branch on `ex.result.all_details`: `404` for the `not_found` detail, and a redirect with `alert:` and `status: :see_other` otherwise
- Enable `verify_authorized_scoped only: :index` in `ApplicationController`
- Remove the `skip_verify_authorized` from all four controllers and narrow the one on `AddressesController` to `new` and `create` once its `index` is scoped
- Add a `relation_scope` to `AddressPolicy` returning the addresses reachable through the acting user's groups and their events, and use it from `AddressesController#index`
- Drop `:group_id` from `member_params` and `event_params`, and `:event_id` from `registration_params`. Each is supplied by the association from the URL, so on `create` the key can only contradict the URL and on `update` it is the only thing that can move the record
- Split `MembersController`'s params in two: `new_member_params` keeps `:user_id` for `create`, `member_params` drops it for `update`, so an existing membership cannot be handed to a different user. `:role` and `:status` stay in both, untouched, since who may set a role is #93 and #96's question
- Cover each controller with request specs asserting the non-member case, the `active` member, the `paused` member and the `inactive` member, per the acceptance criteria on the issue
- Cover the two params holes with their own request specs: an update posting a foreign `group_id` leaves the record where it was, and an update posting `user_id` leaves the membership with the user it had

## Verification

Gates with an exit code, which the implementing agent runs and ticks:

- Every spec below is watched failing before the fix that makes it pass, against the unscoped lookup it replaces, and the round records what it returned
- `verify_authorized_scoped` is watched failing: an `index` is temporarily returned unscoped, the request raises `ActionPolicy::UnscopedAction`, and the scope is put back
- The `404` and the redirect are watched as two distinct outcomes for two distinct causes, not one handler that happens to fire twice
- A `paused` member is watched reading successfully and writing unsuccessfully in the same spec, so the status split is proven to be a split rather than a blanket
- Each params spec is watched failing against the permit list as it stands today, before the key is dropped, so it is known to catch the hole rather than to pass on a technicality
- `bin/ci` is green

Judgement, which only the owner can close:

- [owner] Read the refusal in a browser once, since "a denied link does not produce a blank page" is a claim about what a human sees and no exit code covers it

What these gates cannot see: whether the policies say anything worth saying. Every rule this issue writes is empty of role logic by design, so a spec suite that passes here proves only that the right records are reachable by the right people, never that the right people may do the right things. That is #93 and #96, and no gate on this branch can tell the difference between "role rules deliberately absent" and "role rules forgotten".

## Open questions

None.

## Settled

- **Do the location keys come out of the three nested param lists on this branch?** Yes. Settled by the owner in review: *"OK, I agree then with your reccommendations, lets secure it even more!"* `:group_id` leaves `member_params` and `event_params`, `:event_id` leaves `registration_params`. Proven harmless before the decision rather than after: the key was removed from `registration_params` and the whole suite run, 243 examples and 0 failures, then restored. The association supplies each value from the URL, no form in the application sends any of them, and `action_on_unpermitted_parameters` is `nil` in development and test, so an unpermitted key is dropped rather than raised.
- **Does `user_id` come out of `member_params` on this branch?** On `update` only. Settled by the owner in review: *"OK, lets do it that way then."* `create` keeps it through a separate `new_member_params`, since deciding which person a membership is for is what creating one means; `update` drops it, so an existing membership cannot be handed to a different user with its role and status attached. `:role` stays in both and is deliberately untouched, because who may set a role is #93 and #96's question and this branch must not answer it by accident.

## Noted, not fixed here

`app/views/members/_form.html.erb` has no user field at all, only `status` and `role`, so `user_id` is never sent by the application and only `spec/requests/members_spec.rb` supplies it. Creating a member through the interface therefore cannot work today: `belongs_to :user` has nothing to bind to. That is a separate defect from this branch's and is recorded here rather than folded in.
