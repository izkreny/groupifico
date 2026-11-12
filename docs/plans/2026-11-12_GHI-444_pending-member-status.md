> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add a pending member status (#444)

## Approach

`pending` is appended to `Member`'s status enum, so it is stored as `3` and the existing values keep their integers, per N1. No migration is needed, since the column is already an integer.

**Belonging becomes a named set.** Three places spell "belongs to the group" as `where.not(status: :inactive)`, and each silently admits `pending`: `User#current_memberships`, which every policy scope, the groups index, the group switcher and the feedback form read; `Group#current_members`, which every "N members" count and the member list read; and `RegistrationsHelper#members_available`, which would draw a pending member in the event list form's untickable bucket. A `Member.current` scope, `active` and `paused`, becomes the one spelling, and all three read it. That alone refuses a pending member every group page (AC2): their group leaves every scope, and `ApplicationPolicy#verify_active_membership!` already answers any status other than `active` and `paused` with the `404` a non-member gets.

**A pending member is the owners' alone to see.** `MemberPolicy` gains a pre-check on the record: a pending member is answered with the `404` a non-member gets for anyone but an owner of the group, a paused one included since seeing is a read, because AC3 says the others see neither them nor their details and a plain refusal would confirm they exist. Its `relation_scope` drops pending members for the same readers, so the "Show inactive" toggle, which lists `@group.members`, cannot reveal them to a members administrator either. `MembersController#index` reads `@group.members.where.not(status: :inactive)` rather than `current_members` for its default list, so owners see pending rows there, tagged by the status badge every member row that is not `active` already draws.

**Nobody moves a member into or out of `pending` through the member form.** Leaving `pending` is approving or declining, which #448 owns, so every write rule on a pending record is refused for every column, owners included, and the member row draws no pencil for a pending member, since that row asks `edit?` once per list rather than per row. A validation refuses any update that sets a member's status to `pending`, so an existing member with registrations can never become one and reappear on a roster every member reads; `member_status_choices` stops offering `pending`, and `MembersController#create` sends no welcome mail to a pending member. With no path into `pending` other than creation, AC4 and AC5 already hold through the `active` guards on `Registration#request_response`, `Event#request_all_responses` and `Group#owned_by_anyone_but?`, so their examples are proven against mutations rather than against `main`.

`docs/AUTHORIZATION.md` changes first, per N2, and the policy follows it. The join link, the join request, approval and the waiting screen are #445 to #449, and the styleguide and seeds gain no pending member here.

## Steps

- ::S1:: Rewrite `docs/AUTHORIZATION.md` for `pending`: the status question under `## Two questions, in order`, a Members row giving owners alone the sight of pending members, a paragraph saying a pending member is concealed from every other column with the `404` and that no column changes or removes one through the member form, and a pending owner added to what *An owner is an active owner* does not count (AC6)
- ::S2:: Append `pending` to `Member`'s status enum, add a `:pending` trait to `spec/factories/members.rb`, add the `Member.current` scope and read it from `User#current_memberships`, `Group#current_members` and `RegistrationsHelper#members_available`, with their comments rewritten; extend `spec/models/member_spec.rb` with the stored integer of every status, `spec/models/user_spec.rb` with a pending group absent from `current_groups`, `spec/models/group_spec.rb` with a pending member absent from `current_members`, and `spec/helpers/registrations_helper_spec.rb` with a pending member absent from `members_available` (AC1, AC2, AC3)
- ::S3:: Add the validation refusing an update into `pending` to `Member`, drop `pending` from `member_status_choices`, and skip the welcome mail for a pending member in `MembersController#create`; extend `spec/models/member_spec.rb` with the refused update and an accepted pending creation, and `spec/requests/members_spec.rb` with the status choices the form draws and no welcome mail for a posted `pending` (AC1, AC3, AC4)
- ::S4:: Add the pending-record pre-check and the pending filter to `MemberPolicy`, point `MembersController#index`'s default list at every member who has not left, and draw no pencil on a pending member's row in `app/views/members/_member.html.erb`; extend `spec/policies/member_policy_spec.rb` with `show?`, `edit?`, `update?` and `destroy?` on a pending record for every column of the Members table, a paused owner included, and the scope per column, and `spec/requests/members_spec.rb` with owners seeing a pending row tagged `pending` and no pencil on it, every other column seeing no pending row with the inactive toggle on or off, and `GET`, `PATCH` and `DELETE` on a pending member answered `404` for a non-owner and refused for an owner (AC3)
- ::S5:: Prove the rest: `spec/requests/groups_spec.rb` with a pending member answered `404` on their group and their group absent from their groups index, `spec/policies/group_policy_spec.rb` with a pending member refused `show?`, `spec/models/group_spec.rb` with a pending holder of the owner role never counting under `#owned_by_anyone_but?`, `spec/models/user_spec.rb` with the same under `#solely_owned_groups`, `spec/models/registration_spec.rb` with a pending member's place neither moving nor mailed under `#request_response`, and `spec/models/event_spec.rb` with a pending member left out of `#request_all_responses` and `#fill_list` (AC2, AC4, AC5)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-12_GHI-444_pending-member-status.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-12_GHI-444_pending-member-status.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/member_spec.rb spec/models/user_spec.rb spec/models/group_spec.rb spec/helpers/registrations_helper_spec.rb` passes; the stored-integer example is seen failing against an enum with `pending` inserted before `inactive`, the `current_groups`, `current_members` and `members_available` examples against each scope as it is on `main`, and the refused-update example against `Member` without the new validation
- ::V4:: `mise exec -- bin/rspec spec/policies/member_policy_spec.rb spec/policies/group_policy_spec.rb` passes; the pending-record examples are seen failing against `MemberPolicy` without the pre-check, the paused-owner example against a pre-check asking `active?` instead of belonging, the scope examples against `relation_scope` as it is on `main`, and the group `show?` example against `verify_active_membership!` with a mutation that returns early for `pending`
- ::V5:: `mise exec -- bin/rspec spec/requests/members_spec.rb spec/requests/groups_spec.rb` passes; the member list examples are seen failing against `MembersController#index` and `MemberPolicy` as they are on `main`, the pencil example against the row without its `pending` condition, the choices example against `member_status_choices` as it is on `main`, the welcome mail example against `create` as it is on `main`, and the group examples against `User#current_memberships` as it is on `main`
- ::V6:: `mise exec -- bin/rspec spec/models/registration_spec.rb spec/models/event_spec.rb spec/models/group_spec.rb spec/models/user_spec.rb` passes; the pending examples are seen failing against mutations that replace each `active` guard with `where.not(status: :inactive)` or `!inactive?`, in `Registration#request_response`, `Event#request_all_responses`, `Event#fill_list`, `Group#owned_by_anyone_but?` and `User#solely_owned_groups`
- ::V7:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments app/views/members/_member.html.erb` exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The specs prove who sees and reaches a pending member, not whether `docs/AUTHORIZATION.md` reads as the rule the owner means: AC6 is the owner's to judge from that file in the diff.

## Open questions

None.

## Settled

None yet.
