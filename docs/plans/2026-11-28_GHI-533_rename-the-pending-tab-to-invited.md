> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: rename the pending tab to invited (#533)

## Approach

The label is the `"pending"` value in `Member::Filter::TABS`, and it becomes `"Invited"`. The key, `OVERSEER_TABS` and the `?status=pending` URL stay as they are (N1), so which members the tab lists and who is offered it do not move, and AC2 and AC3 are the existing behaviour kept.

### Prose that names the tab by its label

Every comment, spec description and doc sentence that says "the Pending tab" or "the Pending and Inactive tabs" goes false with the label and becomes "Invited". The ones naming the status, as "a pending member" or "the pending rows", stay, since the status keeps its name until #534. They are `app/controllers/members_controller.rb`, `app/controllers/members/invitations_controller.rb`, `app/views/members/index.html.erb`, `docs/AUTHORIZATION.md`, `spec/models/member/filter_spec.rb`, `spec/requests/members_spec.rb`, `spec/requests/members/invitations_spec.rb`, `spec/system/member_new_page_spec.rb` and `spec/system/members_list_spec.rb`.

### Which examples carry the keys

- AC1 is "counts them on the Pending tab, not the Active one" in `spec/requests/members_spec.rb`, which reads the tab's text with its count.
- AC2 is "lists an invitee under Pending alone" in the same file.
- AC3 is "offers no +, no edit link, and only the Active and Paused tabs" in the same file.

Each keeps its existing WHY and gains a `# WHY: GHI-533 ACn.` line of its own above it, because the criteria gate reads a line holding `GHI-533` and a key, and AC3's existing WHY already names AC1 and AC2 of #484. AC2's and AC3's examples pass on the pre-fix code, since the rename leaves that behaviour alone, so each is watched failing on a mutation instead.

## Steps

- ::S1:: In `app/models/member/filter.rb`, change the `"pending"` label in `TABS` to `"Invited"`. In the same commit, change every tab-text expectation from `Pending` to `Invited` in `spec/models/member/filter_spec.rb`, `spec/requests/members_spec.rb` and `spec/system/members_list_spec.rb`, add the keys *Which examples carry the keys* names, and rewrite the comments and spec descriptions in the `app` and `spec` files *Prose that names the tab by its label* lists
- ::S2:: In `docs/AUTHORIZATION.md`, change "the Pending and Inactive tabs" to "the Invited and Inactive tabs"

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-28_GHI-533_rename-the-pending-tab-to-invited.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-28_GHI-533_rename-the-pending-tab-to-invited.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/member/filter_spec.rb spec/requests/members_spec.rb spec/requests/members/invitations_spec.rb` passes. AC1's example is seen failing on the pre-fix `"Pending"` label. AC2's is seen failing on `#apply` reading `where(status: "active")` whatever the tab, and AC3's on `#offered_tabs` returning `TABS` whatever `oversees?` holds
- ::V4:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V5:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether "Invited" reads right beside Active, Paused and Inactive on a phone-width tab bar. That is the owner's to judge on screen.

## Open questions

None.

## Settled

None yet.
