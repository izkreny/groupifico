> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Make a group's creator an owner member

Implementation plan for [#138](https://github.com/izkreny/groupifico/issues/138). The acceptance criteria live on the issue; this file answers *how*.

## What is actually broken

Read from the code on `main` at `88ece57`, not recalled.

`GroupsController#create` is `@group = Group.new(group_params)` followed by `@group.save`. Nothing else is written, so the group lands with no `Member` rows at all and nobody who can administer it. `Current.user` is never mentioned in the controller, even though the acting user is exactly who the missing membership belongs to.

Since #183 that is no longer only a modelling gap, it is a broken flow. `GroupPolicy` skips the membership pre-checks for `index?`, `new?` and `create?` only, so `show?` still runs `verify_membership!`, which looks for a `Member` row joining the acting user to the group and `deny!(:not_found)`s when there is none. `create` redirects to `group_path(@group)`, so the creator is handed a `404` on the group they just made. The existing request spec asserts the redirect and never follows it, which is why the suite is green.

`Group` has no members-related validation, and it should not grow one on this branch. `User`'s `before_validation -> { build_profile unless profile }` looks like a precedent and is not: `build_profile` conjures a child out of nothing, while a membership needs a user, and the only way a model could learn which one is to reach for `Current.user` from inside itself. A `validates :members, presence: true, on: :create` would also break every bare `create(:group)` in the factories and specs, and the issue's criterion is scoped to the create path rather than to the model.

## Approach

**The membership is built in the controller, next to the request that knows who is acting.** `@group.members.build(user: Current.user, role: :owner)` before the save, so the creator is written by the same code path that reads `Current.user` everywhere else in the app.

**No explicit `transaction` block.** `has_many` autosave already validates records built on a new parent and saves them inside the parent's own save transaction, so `@group.save` is all-or-nothing as it stands. Wrapping it again would add a line that reads as if it were load-bearing when it is not; the criterion is verified by asserting that an invalid create leaves neither a `Group` nor a `Member` behind.

**Authorization is untouched.** `create?` skips both membership pre-checks precisely because there is no group to belong to yet, so building the membership before `authorize!` changes nothing about what is asked or answered. The built record is not persisted, so it cannot satisfy a check either.

**`role: :owner` is written explicitly, not left to the enum default**, which is `member`. `status` is left to its default of `active`, which is what a creator is.

**#93 replaces the role enum with a join table.** Whichever of the two lands second adapts: after #93 the same line creates the membership and its `owner` role row. Nothing here is built for that shape in advance.

## Steps

- Build the creator's membership in `GroupsController#create` as `@group.members.build(user: Current.user, role: :owner)`, before `authorize!`, and let the existing `@group.save` persist both
- Correct the ERD relationship in `README.md` from `MEMBER 0+ to 1 GROUP` to `MEMBER 1+ to 1 GROUP`, confirming first that mermaid's `to` form accepts `1+` rather than assuming it does
- Cover the new behavior in `spec/requests/groups_spec.rb`: the create posts a `Member` for the acting user with the `owner` role, following the redirect now succeeds instead of returning `404`, and an invalid create leaves neither record behind

## Verification

Gates with an exit code, which the implementing agent runs and ticks:

- Every new example is watched failing against the controller as it stands today, before the build line is added, and the round records what each returned
- The `404` example specifically is watched red first, since it is the regression from #183 that the current suite cannot see, and a spec that only ever passes proves nothing about it
- The invalid-create example is watched failing against a deliberately broken version that saves the membership outside the parent's save, so it is known to catch a non-atomic write rather than to pass on a technicality
- `bin/ci` is green

Judgement, which only the owner can close:

- [owner] Create a group in a browser and land on its page rather than a `404`, since the flow this fixes is one a human walks
- [owner] Read the ERD on GitHub once after the change, because nothing in `bin/ci` renders mermaid and a diagram that fails to parse fails silently in the README

What these gates cannot see: whether a group can still end up with zero members by another route. This branch closes the create path only. Removing the last member through `MembersController#destroy` is not guarded, and who may remove whom is a role question that belongs to #93 and #96, so a green suite here says nothing about whether the `1+` in the ERD is an invariant or an intention.

## Open questions

- Should the ERD's `1+` come with a note saying nothing yet stops the last member being removed? The relationship line will claim an invariant the database does not enforce and no code outside `create` upholds. Correcting the cardinality is what the issue asks for; whether the README should also say how far the guarantee reaches is the owner's call, and adding the note is one bullet in the diagram's `IMPORTANT` block.

## Settled

None yet.
