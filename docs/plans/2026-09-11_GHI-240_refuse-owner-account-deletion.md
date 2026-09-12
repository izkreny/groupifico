> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Refuse deleting an owner's account

Implementation plan for [#240](https://github.com/izkreny/groupifico/issues/240). The issue holds the acceptance criteria; this answers how.

## Why the existing guard does not already catch this

`Member#ensure_the_group_keeps_an_owner` is the guard that refuses removing a group's last owner, and it returns early on `destroyed_by_association`. That flag is set by *any* parent destroy, not only the group's, so `User#destroy!` cascading `has_many :members, dependent: :destroy` walks straight past it - the comment above it names the group case, which is the case it was written for and the only one it can tell apart. Widening that early return is not the fix: a `Member` sees one group at a time, and criterion 1 asks for the response to name *each* group the account still owns, which only the user end can collect.

## Approach

`User` gains `solely_owned_groups`, which selects the groups where the user's own active owner membership is the last one standing, and a `before_destroy` throwing `:abort` while that set is non-empty. `destroy!` then raises `ActiveRecord::RecordNotDestroyed`, and `UsersController` answers it with a redirect and an alert, the way `MembersController` already answers the same exception from the group end.

The predicate is `Group#owned_by_anyone_but?`, reused rather than reimplemented: it already asks "does an *active* owner other than this member exist", which is exactly criterion 1's "only active owner". So the collection is the user's active owner memberships, rejecting those whose group still has another owner, mapped to the groups.

**`prepend: true` on the callback is load-bearing**, the same trap `Member` documents for its own guard. `has_many :members, dependent: :destroy` registers its own `before_destroy` when the association is declared, so a guard declared after it runs with the memberships already destroyed inside the transaction, `solely_owned_groups` reads empty, and the account is deleted anyway.

`solely_owned_groups` is the one method criterion 3 asks for: the callback asks it, the controller's alert names the groups it returns, and `users/show` renders the block when it is non-empty. Nothing asks the question a second way, so the view and the controller cannot disagree.

## What this branch does not do

The issue is labelled `backend` and no criterion reaches the sheet's controls, so **frame 9i's type-to-confirm field and its disabled button are out of scope**. What is taken from 9i is the block's copy, because criterion 1 asks the response to name the groups: "You still own <name>. Give another member the owner role first." The account screen gets that block above the delete control when the reader owns a group solely; the control itself keeps working and the model refuses the request, which is what makes the rule true rather than merely displayed.

The assumption this rests on: the block plus the alert satisfies "the response names each such group", and the type-to-confirm sheet is a later frontend row rather than part of this one.

## Steps

- Add `User#solely_owned_groups`, collecting the groups of the user's `active` owner memberships that `Group#owned_by_anyone_but?` answers false for, with a comment saying why the question is asked from this end rather than from `Member`.
- Add `before_destroy :ensure_no_group_loses_its_only_owner, prepend: true` to `User`, throwing `:abort` while `solely_owned_groups` is non-empty, with a comment on why `prepend: true` is load-bearing.
- Add `rescue_from ActiveRecord::RecordNotDestroyed, with: :refuse_ownerless_groups` to `UsersController`, redirecting to `user_path` with an alert naming each group from `solely_owned_groups`, mirroring `MembersController#refuse_ownerless_group`.
- Render the 9i block on `app/views/users/show.html.erb` when `@user.solely_owned_groups` is non-empty, naming each group and what to do about it.
- Add model examples to `spec/models/user_spec.rb`: `solely_owned_groups` answers a group where the user is the only active owner, answers one whose second owner is `paused` or `inactive`, omits one with a second active owner, and omits one the user is a plain member of; destroying a sole owner is refused with the user and every membership left standing; destroying a user who owns nothing succeeds.
- Add request examples to `spec/requests/user_spec.rb` for `DELETE /user`: the sole owner is redirected to `user_path` with the alert naming the group and the account survives, and a user owning nothing is destroyed as today.

## Verification

- `bin/ci`

Both the callback and its `prepend: true` are proved by watching the model example fail first: with the callback absent the sole owner is destroyed, and with `prepend: true` dropped it is destroyed too, because the memberships are gone before the guard reads them. The request example is what proves the controller answers a refusal rather than a 500.

What those gates cannot see: whether the block on the account screen reads the way frame 9i intends, which is the owner's judgement, and the browser suite, which `bin/ci` runs but which asserts nothing about this rule.
