> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Reach the acting member through Current

Implementation plan for [#227](https://github.com/izkreny/groupifico/issues/227). The issue holds the acceptance criteria; this answers how.

## Approach

`Current` gains one attribute and one method. `attribute :group` is assigned per request from `params[:group_id]`, because nothing already in `Current` can answer it: `Current.session` knows a `User`, and a user has many groups. `member` is a plain public instance method reading `group.members.find_by(user:)`, and `CurrentAttributes.method_added` generates the class-level delegator for it - verified in the installed gem at `current_attributes.rb:185-197`, which delegates every public instance method that is not `initialize` and not already a singleton method.

The assignment lives in one new concern, `app/controllers/concerns/group_scoped.rb`, because `EventsController`, `MembersController` and `RegistrationsController` carry a byte-identical `set_group` today. Including it deletes two copies of that method rather than adding a layer over three distinct ones.

`Event`'s `creator` default then reads `Current.member` instead of deriving the membership from the event's own group. **This does change behaviour**, in two places, and the issue's original "changes no behaviour" claim was wrong. Inside a request the result is identical, because every controller that creates an event is nested under the group it is created in. Outside one - a console, a job, `db/seeds.rb` - the old lambda filled the creator from the event's own group and the new one answers nil, so the required association refuses the save. And the guarantee the old derivation carried structurally, that a creator belongs to the event's group, is now stated as a validation rather than lost.

## Why `member` is not memoized

`ActiveSupport::CurrentAttributes#reset` is `self.attributes = resolve_defaults` (`current_attributes.rb:228-232`): it replaces the attributes hash and touches nothing else. An `@member ||=` ivar sits outside that hash, so it would survive the executor's reset and hand the next request on the same thread the previous request's member. The method therefore queries on each call, and a comment says why rather than leaving the missing memo to read as an oversight.

The call count that buys is small: one call per event creation today. If a later caller makes it hot, the fix is a second `attribute` assigned alongside `group`, not an ivar.

## What the concern assigns

```ruby
def set_group
  @group = Group.find(params.expect(:group_id))
  Current.group = @group
end
```

Both, rather than making `@group` a reader over `Current.group`. Criterion 3 keeps `@group` available to every action and view that reads it, and every one of those reads is a view rendering a path helper - `group_events_path(@group)` and its siblings - so turning the ivar into a method call would touch the views for no gain the issue asks for.

`include GroupScoped` goes exactly where each `before_action :set_group` sits now, which keeps it ahead of `set_event`, `set_member` and `set_registration`. In `members_controller.rb` that is below the two `rescue_from` lines, which are not callbacks and do not compete for position.

## The owner's addendum, and what it does not reach

The instruction alongside the command was to implement this everywhere it is used in current form. Two sites are candidates and neither is taken in this branch:

- **`ApplicationPolicy#membership` (`application_policy.rb:58`)** asks the same question with `Member.find_by(group: group_for(record), user: user)`. The issue already puts it out of scope, and three facts make it a change of behaviour rather than a swap. `GroupsController#set_group` reads `params.expect(:id)`, so `Current.group` is nil on every `GroupPolicy` check that runs the pre-checks and `show?`, `edit?`, `update?` and `destroy?` on a group would all answer 404. Every policy spec supplies `context: { user: actor.user }` and sets neither `Current.session` nor `Current.group`, so the whole `spec/policies` tree would fail. And the policy's group comes from the record while `Current.group` comes from the URL: they agree today only because the nested controllers scope every lookup through `@group`, which is a property of the callers rather than of the policy. This is the finding the owner asked to be told about; the owner settled it, and the decision is under `## Settled`.
- **`GroupsController#set_group`** is not the same form: it finds by `:id`, and a group is not nested under a group. The concern cannot absorb it. Whether `GroupsController` should nonetheless set `Current.group` turns on the policy question above, and was settled with it.

## Steps

- Add `attribute :group` to `app/models/current.rb`, with a comment saying it is assigned per request because nothing in `Current` can derive it.
- Add the public `member` method to the same class, reading `group.members.find_by(user:)` and answering `nil` where either is absent, with the no-memoization comment.
- Add `spec/models/current_spec.rb`: `member` answers the membership when both are set, `nil` with no group, `nil` with no session, and `nil` when the acting user's only membership is in another group.
- Add `app/controllers/concerns/group_scoped.rb` with `included { before_action :set_group }` and the private `set_group` above.
- Replace `before_action :set_group` with `include GroupScoped` in `events_controller.rb`, `members_controller.rb` and `registrations_controller.rb`, and delete all three `set_group` definitions.
- Change `Event`'s `creator` default to `-> { Current.member if new_record? }` and rewrite the comment above it: the `new_record?` paragraph stays and is still load-bearing, the paragraph explaining why it does *not* read `Current.member` is replaced, and the safe-navigation paragraph goes with the two `&.` it explains.
- Update the four `creator` examples in `spec/models/event_spec.rb` to set `Current.group` alongside `Current.session`, and make the "another group" example set `Current.group` to the event's group so it still fails for the reason it names rather than because `Current.group` is nil.
- Add one example to `spec/models/event_spec.rb` proving the creator is `nil` when `Current.group` is unset, which is the console, job and seeds case the old lambda answered from `group` and this one cannot.
- Added in the review round, on RF1: `validates :creator, inclusion: { in: ->(event) { event.group&.members || Member.none } }, allow_nil: true` on `Event`, restoring in the model the cross-group guarantee the default gave up, with the two refusal examples and the same-group control. The `|| Member.none` fallback is load-bearing: without it a groupless event hands the validator nil and `include?` raises.

## Verification

- `bin/ci`

The behaviour this branch does change is stated under *Approach* rather than left to be inferred, and each half of it is asserted: the out-of-request case by "is invalid when no group is being acted in", and the cross-group refusal by the two RF1 examples.

What those gates cannot see: criterion 4, that `AddressesController` leaves `Current.group` and `Current.member` nil. A request spec cannot assert it, because the executor resets `Current` before the example reads it, so any such assertion passes whether the concern is included or not. It is satisfied by construction - the controller does not include `GroupScoped` - and the diff is the evidence. `spec/models/current_spec.rb` covers the half that is testable, that `member` is nil with no group.

Two checks are watched failing before they are trusted. The new "creator is nil when `Current.group` is unset" example is run against the old derived lambda, where it passes for the wrong reason, and must go red only once the lambda changes. The "another group" example is run with `Current.group` deliberately unset, where it passes vacuously, before the group is set and it starts proving the scoping again.

The behaviour claim itself - that the same member is recorded on create as today - is proved by `spec/requests/events_spec.rb`, which creates events through the real controller stack. Its assertion is untouched by this branch; only the comment above it changes, because that comment named `Current.user` as what the default reads.

## Open questions

None.

## Settled

- **Should `ApplicationPolicy#membership` read `Current.member`?** No, and not as a follow-up either. `spec/policies/` never mentions `Current`: all 111 examples across its six files are built on a bare `let(:context) { { user: actor.user } }`. They can be, because `ApplicationPolicy` derives the group from the record through `group_for` and so can be asked about any record in isolation. Reading `Current.member` would make every policy depend on a controller having set an ambient variable first, which is not an editing cost to those specs but the loss of the property they exist to test. The duplicate `Member.find_by` buys that isolation and stays.
- **Should `GroupsController` set `Current.group` from `params[:id]`?** No. The concern cannot absorb it - that controller finds by `:id`, on four of its six actions - so it would be a bare line in its own `set_group`, and nothing in that controller reads `Current.member`. Its only justification was being step one of the question above, which is dropped, so the assignment would have no reader. `Current.group` and `Current.member` are for where they are convenient and correct, not for everywhere the question is asked.
