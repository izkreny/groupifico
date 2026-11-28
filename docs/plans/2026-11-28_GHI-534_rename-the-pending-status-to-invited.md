> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: rename the pending status to invited (#534)

## Approach

The enum key `pending: 3` in `Member::Statuses` becomes `invited: 3`, and everything that names the status follows it in one commit: the state machine's state and its `join` transition, the scope and predicate callers, the validation that refuses a move into the status and its message, `MemberPolicy`'s pre-check, the controllers, the members helper, the factory trait, the styleguide, every comment and spec description, and `Member::Filter`'s `TABS` and `OVERSEER_TABS` keys. The filter has to move in the same commit as the enum, because `#counts` keys its tallies by the enum's names while `TABS` holds literals, so renaming one without the other counts the Invited tab as 0 and raises nothing.

### No data migration, against N1

N1 expects a data migration for the member rows and the status changes, and none is needed: `members.status` and `member_status_changes.status` are both integer columns, `Member::StatusChange` declares its enum from `Member.statuses`, and the integer stays 3. Every row stored as pending today reads as invited the moment the key is renamed, its status changes included, which is AC2. A migration rewriting 3 to 3 would be code with nothing to do, so the plan writes none, and AC2 is proven by an example that writes the raw integer to both tables and reads `invited` back.

### What stays `pending`

The word stays wherever it is not this status, so the reviewer can tell a survivor from a miss:

- `Redeemable.pending(token)` and its caller in `app/controllers/concerns/emailed_link_token.rb`, a link not spent yet, which is a different concept.
- `ActiveRecord::PendingMigrationError` in `spec/rails_helper.rb`, the pending migrations comment in `config/environments/development.rb`, and "depending" and "Spending", which only contain the letters.
- The `GHI-533` WHY lines in `spec/requests/members_spec.rb` that say where "Pending" was, because they record that issue's criteria.
- Everything under `docs/adr/` and `docs/plans/`, which records decisions as they were made.

"A pending" becomes "an invited" wherever the article precedes it.

### Which examples carry the keys

- AC1 is the two `define_enum_for(:status)` examples, in `spec/models/member_spec.rb` and `spec/models/member/status_change_spec.rb`, now reading `invited: 3`. No example asserts that `pending` is absent, since the values list is exhaustive.
- AC2 is a new example in `spec/models/member_spec.rb` that writes the integer 3 to a member's row and to its status change with `update_all`, then reads both back as `invited`.
- AC3 is two examples in `spec/requests/members_spec.rb`: the existing "lists an invitee under Invited alone", now reaching the tab at `?status=invited`, and a new one where an overseer's `?status=pending` lists the Active members and no invitee.
- AC4 is the existing Join and Decline examples in `spec/requests/groups/invitations_spec.rb`, "makes them an active member and opens the group" and "removes the invited membership, keeps the user and lands on the root page".
- AC5 is the closing grep in V4, run over `docs/AUTHORIZATION.md` among the rest, since nothing in the spec suite reads that file.

Each keyed example gains a `# WHY: GHI-534 ACn.` line above its existing WHY. AC4's examples pass on the pre-fix app code once their factory trait is renamed back, so each is watched failing on a mutation instead.

## Steps

- ::S1:: Rename the status from `pending` to `invited` in `app` and `spec` in one commit, per the approach: `app/models/member/statuses.rb`, `app/models/member/filter.rb`, `app/policies/member_policy.rb`, `app/controllers/members_controller.rb`, `app/controllers/members/invitations_controller.rb`, `app/controllers/groups/invitations_controller.rb`, `app/controllers/styleguides_controller.rb`, `app/helpers/members_helper.rb`, the views and comments the survey found, `spec/factories/members.rb` and every spec naming the status, with the AC1 to AC4 keys and the two new examples
- ::S2:: In `docs/AUTHORIZATION.md`, name the status `invited` wherever it names `pending`

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-28_GHI-534_rename-the-pending-status-to-invited.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-28_GHI-534_rename-the-pending-status-to-invited.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/member_spec.rb spec/models/member/status_change_spec.rb spec/requests/members_spec.rb spec/requests/groups/invitations_spec.rb` passes. AC1's and AC2's examples are seen failing on the pre-fix `pending: 3` key, AC3's `?status=pending` example on the pre-fix `"pending"` key in `Member::Filter::TABS`, and AC4's Join and Decline examples on `Groups::InvitationsController#set_invited_member` reading `members.current` instead of `members.invited`
- ::V4:: `grep -rnE '(\b|_)pending' app spec config docs/AUTHORIZATION.md` prints only the lines in `app/models/concerns/redeemable.rb`, `app/controllers/concerns/emailed_link_token.rb` and `config/environments/development.rb`, seen listing the status's mentions before S1
- ::V5:: `grep -rnE '\b[Aa] invited' app spec docs/AUTHORIZATION.md` prints nothing
- ::V6:: `mise exec -- bin/rubocop` and `node_modules/.bin/herb-lint --ignore-disable-comments` exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see two things. A bookmarked `?status=pending` link now opens the Active list without saying why, which AC3 accepts and an overseer may notice. And production's own rows are covered only by the integer example, not by reading them back after the deploy.

## Open questions

None.

## Settled

None yet.
