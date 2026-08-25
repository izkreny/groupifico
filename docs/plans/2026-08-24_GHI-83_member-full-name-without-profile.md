> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fix member full_name for users without a profile (#83)

## Approach

Every `User` must have a `UserProfile`; that is the design, settled in the plan discussion on the PR, so the fix makes the invariant true at creation instead of tolerating the hole at read time.

`User` gains the whole guarantee, on the model so every creation path is covered (signup, console, seeds, specs, and any future controller):

```ruby
before_validation -> { build_profile unless profile }, on: :create
validates :profile, presence: true, on: :create
```

`has_one` autosaves a newly built profile in the same transaction as the user. `on: :create` keeps the rule off later saves of existing rows.

Around it: the profile destroy action goes away entirely, button and route included, because a resource that must always exist has nothing to delete; the later anonymisation work owns reset semantics. `Member` keeps `delegate :full_name, to: :profile`, which now never sees nil, and `UserProfile#full_name` keeps its email local-part fallback, which is exactly what a fresh blank profile should display. No backfill migration: there are no real users yet, and development databases get their profiles from reseeding.

The `README.md` ERD moves from `USER 1 to zero or one USER_PROFILE` to 1 to 1.

## Steps

- Add the creation invariant to `User`: `before_validation` profile build plus presence validation, both `on: :create`
- Remove the profile destroy: the controller action, its route, and the view button
- Adapt the `user_profile` factory and the seeds to the auto-created profile (a created user already owns one, and the unique index on `user_id` forbids a second)
- Specs: creating a `User` through any path yields a profile; a `User` cannot be created without one; `Member#full_name` answers the email local part for a fresh blank-profile signup; the existing `UserProfile` specs keep passing
- Update the `README.md` ERD to 1 to 1 and tick the issue criteria as they land

## Verification

- The new invariant specs fail against the current code before the fix lands (red seen before green)
- `bin/ci` passes on this branch
- The docs check on this plan file and the README passes

What these gates cannot see: whether removing the profile delete button reads as a regression to a user of the profile page; the owner sees that on the diff, not a spec.

## Open questions

None.

## Settled

- Option 2 (read-time fallback) or option 1 (profile always exists)? The owner chose the invariant: every User must have a UserProfile, by design.
- Fold `UserProfile` into `users`? Withdrawn after verifying fizzy in the reference clones: fizzy has no profile model because its per-account Users are silos, while this app's groups share one user base, so member-level person data would duplicate. The split stays.
- Guarantee mechanism: model-level build-plus-validation on create, covering every path, rather than a controller-called method that guards only its own path; fizzy itself pairs its controller-called methods with exactly such a validation backstop.
- Profile destroy: removed rather than turned into a field reset; anonymisation work later reintroduces reset semantics deliberately.
- No backfill migration: no real users exist yet, development databases reseed.
