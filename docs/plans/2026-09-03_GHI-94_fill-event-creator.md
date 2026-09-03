> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fill an event's creator automatically (#94)

## Approach

`belongs_to`'s own `default:` lambda fills `creator` when nothing else has, and the parameter that lets a caller name one comes out of `EventsController` and off the form. Rails installs that lambda as a `before_validation` through `ActiveRecord::Associations::Builder::BelongsTo.add_default_callbacks`, so it runs on every create path and skips any event whose creator is already set.

**The lambda derives the member from the event's own group rather than from a new `Current.member`, which is a deviation from the issue's technical notes.** `@group.events.new` has already set `group_id` by the time the callback runs, so `group.members.find_by(user: Current.user)` is answerable there, and `Current.user` exists today. A `Current.member` would have to be assigned by a `before_action`, and one assigned by `EventsController` alone is `nil` under every other controller in the app, which is a trap rather than an affordance: Fizzy avoids it by setting `Current.user` on every request, and its own account default is the derived shape this plan uses, `belongs_to :account, default: -> { user.account }`. Nothing in `docs/` records `Current.member` as a decision, so this contradicts a note rather than a record. The issue's acceptance criteria name no mechanism and none of them moves.

`group&.` is load-bearing: the callback runs before the `group` presence check, so `Event.new.valid?` would raise instead of collecting its errors.

**A `nil` creator is unreachable through the controller**, because `ApplicationPolicy#verify_membership!` refuses a non-member with a 404 before any rule runs. The model still refuses it, since `belongs_to :creator` is required, and that is what the model spec asserts rather than a path a request can take.

`foreign_member?` stays, because `manager_id` is still submitted and still checked. What goes with the creator parameter is its own line in the `.tap` block, and the comments above both methods, which describe a parameter set that no longer holds.

## Steps

- Watch it fail first: assert that an event built in a group with that group's member signed in comes out with them as creator, and see it come back `nil` on the unmodified tree
- Add `default: -> { group&.members&.find_by(user: Current.user) }` to `Event`'s `creator` association
- Drop `:creator_id` from `EventsController#event_params` and its line from the `.tap` block, and rewrite the comments above `event_params` and `foreign_member?`
- Remove the creator label and `collection_select` from `app/views/events/_form.html.erb`, leaving the manager pair's alignment as it stands
- Add the model spec for the default: the acting member becomes the creator, an explicitly assigned creator wins, and a `Current.user` who is not a member of the group leaves the event invalid
- Make the events administrator's create example the request-level proof: post no `creator_id`, assert the created event's creator is the signed-in member, and drop the parameter from the other create examples where it is now noise
- Replace the update example that ignored another group's `creator_id` with one posting a member of the event's own group, asserting the creator is unchanged
- Add the duplicate example: the member who duplicates an event becomes the new event's creator, not the original's
- Confirm `db/seeds.rb` and the event factories still plant, since both assign `creator` directly and neither has a `Current.user`

## Verification

- `bin/ci` passes
- `grep -rn creator_id app/controllers app/views` finds nothing
- The model spec for the default has been seen red before the association changed

`bin/ci` covers every path a request spec already walks, and the model spec covers the callback itself. What none of them sees is a create path that does not exist yet: the default answers for whatever `Current.user` holds at the time, so a future job or console caller with no session gets a `nil` creator and a validation error rather than a wrong one. That is the intended failure mode and not something a gate can prove today.

## Open questions

None.

## Settled

- Where does the acting member come from? The event's own `group` and `Current.user`, inside the `default:` lambda, rather than the `Current.member` the issue's notes named. `Current.member` set by one controller reads `nil` in every other, and the group is already on the record when the callback fires.
