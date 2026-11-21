> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let link joiners in without approval (#504)

## Approach

`JoinRequestsController#create` drops `create_with(status: :pending)`, so the membership `find_or_create_by` builds takes the `active` a member is created with by default. The lookup stays as it is, so a second press or a page left open still leaves an existing membership of any status alone, an `inactive` one included.

The redirect stays on the join page, which already answers an active member with "You are already in this group." and an "Open" button, so no new screen or copy is built for the moment after joining. The "Ask to join" button keeps its label, which the issue's own wording uses.

Three pieces of prose become false and are rewritten: the `skip_verify_authorized` justification and the `create` WHY comment in the controller, which both rest on the member starting `pending`, and the join paragraph in `docs/AUTHORIZATION.md`, which says the same. The join link dialog's hint, "You approve each request.", is the one sentence a group's owner reads that becomes false, so it goes too.

N3's first status change has nowhere to land yet: `Member::StatusChange` arrives with #126, which is still open, and its backfill gives every existing member one change dated the day their membership was created, a link joiner included. N4 needs no code, because only `MembersController#create` sends the welcome mail. The general `pending` wording in the policies, the model and `docs/AUTHORIZATION.md` stays, since pending members already exist and #505 creates more.

## Steps

- ::S1:: In `app/controllers/join_requests_controller.rb`, drop `create_with(status: :pending)` from `create`, and rewrite the `skip_verify_authorized` comment and the `create` WHY comment so neither claims the member starts pending
- ::S2:: In `docs/AUTHORIZATION.md`, rewrite the join paragraph's sentence on pressing "Ask to join" so `create` adds the visitor as an `active` member who reaches the group like any other
- ::S3:: In `app/views/groups/_join_link.html.erb`, rewrite the hint so it no longer says the owner approves each request
- ::S4:: In `spec/requests/join_requests_spec.rb`, turn the #447 AC2 pending example into #504 AC1, the visitor added as an active member and returned to the join page, and add an AC2 example where the new member then gets the group's page
- ::S5:: In `spec/system/join_page_spec.rb`, turn the example that lands on the request waiting for approval into one that lands on "You are already in this group." and follows "Open" to the group's page

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-504_link-joiners-skip-approval.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-504_link-joiners-skip-approval.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; the AC1 and AC2 examples are seen failing against `main`'s `create`, with `create_with(status: :pending)` restored
- ::V4:: `mise exec -- bin/rspec spec/system/join_page_spec.rb` passes; the changed landing example is seen failing against `main`'s `create`
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files and `herb-lint` over the changed view exit 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot judge whether "You are already in this group." reads right to somebody who pressed the button a moment before, or whether "Ask to join" still fits a button that lets them straight in; both are the owner's to judge and would be their own copy issue.

## Open questions

None.

## Settled

- None yet.
