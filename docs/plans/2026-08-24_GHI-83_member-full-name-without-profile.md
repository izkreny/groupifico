> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fix member full_name for users without a profile (#83)

## Approach

Of the issue's three options, this plan recommends option 2, refined so the nil handling lives in exactly one place instead of spreading to callers: the display-name decision moves to `User`, which owns both inputs (the email and the profile), and `Member` delegates to it.

- `User#full_name`: `profile&.full_name || email.split("@").first`. When a profile exists, `UserProfile#full_name` already answers everything, including the blank-names fallback; the `||` branch fires only when the profile is missing, whatever removed it.
- `Member`: `delegate :full_name, to: :user`. `belongs_to :user` is required, so the delegation target can never be nil. `UserProfile#full_name` and every view caller stay untouched.

Why not option 1 (create the profile with the User, make it required): it needs a signup-path callback, a backfill migration, a rethink of `UserProfilesController#destroy` (which can legally remove a profile today and would recreate the hole), and it couples to #139's pending signup rework, all to guarantee an invariant that read-time handling makes unnecessary. The issue's own anonymisation note wants "profile missing" and "profile blank" to give the same answer, and this shape gives both the email local-part through the same path. Option 3 (profile as a signup step) adds friction and waits on #139 regardless.

The ERD in `README.md` currently says `USER 1 to zero or one USER_PROFILE`; under this decision that stays true and needs no edit, only confirmation.

## Steps

- Move the display-name fallback to `User#full_name` and switch `Member` to `delegate :full_name, to: :user`
- Update the `Member` delegation spec to the new target, add `User#full_name` specs (with profile, with blank-name profile, without profile), and add the acceptance-criterion spec: a `Member` whose `User` has no profile answers `full_name` with the email local part
- Confirm the `README.md` ERD needs no change and tick the issue criterion that asks for it

## Verification

- The new no-profile specs fail against the current code before the fix lands (red seen before green)
- `bin/ci` passes on this branch
- The docs check on this plan file passes

What these gates cannot see: whether the email local part is the display name the owner actually wants in member lists; the specs pin the behaviour, not its desirability.

## Open questions

- Option 2 as refined here (read-time fallback on `User`, no schema or signup change) over option 1 (profile always exists): does the owner agree with the recommendation and its reasons above?

## Settled

None yet.
