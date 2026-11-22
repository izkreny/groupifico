> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: land link joiners in their group (#517)

## Approach

`JoinRequestsController#create` keeps `find_or_create_by` and branches on the membership it returns. Where `previously_new_record?` is true, the press just made the visitor a member, so it redirects to `group_path(@group)` with the notice "You joined {group}." and `status: :see_other`, exactly as `Groups::InvitationsController#update` does. Every other case keeps the redirect to the join page it has today.

`previously_new_record?` is set only after a successful insert, in Active Record's `_create_record`, so it is false for a membership that already existed and false for the unsaved record the no-bang create returns when two presses race and the later one is refused. Both fall through to the join page, which is what AC2 and N2 ask for, and the WHY comment on `create` gains the reason only a fresh membership lands in the group.

`docs/AUTHORIZATION.md` says only that `create` adds the visitor as an `active` member who reaches the group like any other, never where the press lands, so it stays as it is.

## Steps

- ::S1:: In `app/controllers/join_requests_controller.rb`, branch `create` on `previously_new_record?`: a membership just created redirects to the group's page with the notice "You joined {group}." and `status: :see_other`, anything else to the join page as before; extend the `create` WHY comment, still one line, with why only a fresh membership lands in the group
- ::S2:: In `spec/requests/join_requests_spec.rb`, turn the #504 AC1 example's redirect into #517 AC1, the visitor added as an active member and redirected to the group's page, and give each of the four "leaves a … member as they are" examples a `flash[:notice]` that is nil, as #517 AC2
- ::S3:: In `spec/system/join_page_spec.rb`, turn the example that lands on "You are already in this group." and follows "Open" into #517 AC1 walked in the browser: the press lands on the group's page showing "You joined Riverside Choir."

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-22_GHI-517_land-link-joiners-in-their-group.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-22_GHI-517_land-link-joiners-in-their-group.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; the #517 AC1 example is seen failing against `main`'s `create`, and the four #517 AC2 examples, which pass on `main`, are seen failing against the mutation that redirects every press to the group's page with the notice
- ::V4:: `mise exec -- bin/rspec spec/system/join_page_spec.rb` passes; the changed landing example is seen failing against `main`'s `create`
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot judge whether landing on the group's page with "You joined {group}." reads right straight after pressing "Ask to join", rather than after an invitation's Join; that is the owner's to judge.

## Open questions

None.

## Settled

- None yet.
