> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: land a one-group member on their group (#498)

## Approach

`GroupsController#index` serves both `/` and `/groups`, so it is the one place every way home passes through: sign-in, the profile form's Save, a refusal's redirect, a destroyed group and every Back or Cancel that leads home. After its `authorize!`, it loads the authorized scope once and, when that holds exactly one group, redirects to that group's page before building `@memberships`; otherwise it renders the list as today. The authorized scope is `GroupPolicy`'s `relation.merge(user.current_groups)`, the set N1 and N2 name, so active and paused memberships count and pending and inactive ones do not, without a second query.

The redirect adds a hop to every flow that sets a flash and then goes home: `deny_access`'s alert, `destroy`'s notice, the profile Save's notice and `refuse_authenticated`'s "You are already signed in.". A flash lives for exactly one following request, so the redirecting request would spend it unseen. The redirect therefore calls `flash.keep`, so the message reaches the group page it lands on.

Existing specs that read the list as a member of one group, or expect a one-group member to come to rest on `/`, now see the redirect. Each is kept asserting what it was written for by giving its member a second current group, or by moving the expected path to the group page where landing there is the new behaviour, never by weakening the assertion.

## Steps

- ::S1:: In `app/controllers/groups_controller.rb`, make `index` load `authorized_scope(Group.all)` once after `authorize!`, and when it holds exactly one group call `flash.keep` and redirect to `group_path` of that group, returning before `@memberships` is built
- ::S2:: In `spec/requests/groups_spec.rb`, add a "home for a member of one current group" block: an active one-group member is redirected from `/` and from `/groups` to the group page (AC1); a paused one-group member is redirected too (AC1, N2); a member of two current groups gets the list (AC2); a user with no membership, and one whose only membership is pending, get the list (AC3); a member active in one group and pending in another, and one active in one and inactive in another, land on the active group (AC4); and a paused one-group owner refused the edit form follows both hops and finds the alert on the group page
- ::S3:: In `spec/requests/sign_ins_spec.rb`, add an example where a member of one group spends a sign-in link and, following the redirects, lands on the group page (AC1)
- ::S4:: Keep the existing specs asserting what they were written for: in `spec/requests/groups_spec.rb`, give the member in each `GET /groups` list and card example a second current group; in `spec/system/groups_index_spec.rb`, the same; in `spec/system/group_refusal_spec.rb`, expect the refused paused owner to land on the group page with the alert painted; in `spec/system/authentication_spec.rb`, expect a one-group member signing in to land on the group page (AC1); and fix any further example `bin/ci` turns up by the same rule

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-498_land-one-group-member.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-498_land-one-group-member.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/groups_spec.rb spec/requests/sign_ins_spec.rb` passes; the AC1, AC4 and sign-in examples are seen failing against `main`'s `index`; the flash example against the branch's `index` with `flash.keep` removed; the AC2 example against the branch's condition loosened to any group; the AC3 examples against the condition loosened to at most one group; and the AC4 pending and inactive examples against `authorized_scope(Group.all)` swapped for `Current.user.groups`
- ::V4:: `mise exec -- bin/rspec spec/system/groups_index_spec.rb spec/system/group_refusal_spec.rb spec/system/authentication_spec.rb` passes; the group refusal alert example is seen failing against the branch's `index` with `flash.keep` removed
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The specs prove where each kind of member lands and that a flash survives the extra hop; they cannot see whether skipping the list ever strands a one-group member who wanted it, which the "New group" entry in the me menu is meant to cover and is the owner's to judge.

## Open questions

None.

## Settled

- None yet.
