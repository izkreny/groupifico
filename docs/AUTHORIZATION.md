> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Authorization

Who may do what inside a group, and why the code answers it the way it does. The mechanism is Action Policy, adopted in [ADR 0003](adr/2026-08-25_authorization-with-action-policy_0003.md); this document is the model that sits on top of it.

## Specification, or record?

Both, and the difference matters when the two disagree.

**A record, enforced today:** the two questions below, the status filter that answers the second, and everything in `## Records that have no group at all`. Each describes code that exists, so where this document and the code disagree, the code is right and this document is a bug.

**A specification, enforced by nothing yet:** every mark in the capability tables. No policy consults a role, so a marked cell is a decision waiting for #96 and #173 to write the rule and the example that prove it. Until then a mark tells you what the application will do, never what it does.

## Two questions, in order

Every request inside a group asks these, in this order, and the second one is a status question rather than a role one.

1. **Does the acting user belong to this group?** No `Member` row means the record does not exist for them: `404`, not `403`, so the response does not confirm the id exists. `ApplicationPolicy#verify_membership!` is the authority, and [ADR 0003](adr/2026-08-25_authorization-with-action-policy_0003.md) records why the refusal is a `404` rather than a `403` and what that choice is worth. The reasoning lives there and is deliberately not copied here.
2. **What does their status permit?** `inactive` has left and is refused exactly like a non-member, with the same `404`. `paused` still belongs and keeps every read row below, losing every other row. `active` is the only status where the tables are consulted in full. `ApplicationPolicy#verify_active_membership!` is the authority, and `ApplicationPolicy::WRITE_RULES` is what it counts as a write.

Status is orthogonal to role, which is why it is stated here once instead of as three more columns: multiplying the two axes would make two thirds of the cells duplicates of each other.

A member who belongs but lacks the role gets `403` rather than `404`. Concealment from somebody who can already see the group in the interface is noise rather than security, and the split is the one ADR 0003 records.

## Capabilities

A cell marked `x` means the column grants the capability. A blank means it does not, and reads as "not granted" rather than as "not decided".

**`member` is the first column and is not a role.** Everyone who belongs to the group is a member, and belonging is a `Member` row with an `active` status rather than anything in `roles`. It earns a column because the reads it grants are capabilities like any other. Every role holder is also a member, so a row marked under `member` is granted to every column beside it; those rows are marked right across anyway, so a row can be read left to right without holding that rule in your head.

**The role columns combine.** A member's permissions are the union of the rows for every role they hold, so a member holding `events_administrator` and nothing else gets that column plus `member`. `owner` is a superset of `administrator` row by row rather than by the word carrying it.

**`manager` is the one column scoped to a single record.** It is not a role and holds no row in `roles`: it is `events.manager_id` pointing at a `Member`, so a mark under it grants the capability on the one event that member manages and never on the group's other events. That is why it appears only in the events table, and why the role columns beside it mean every event in the group.

**`creator` is not a column at all.** `events.creator_id` records who made the event and grants nothing. The member who created an event may well be an `events_administrator` today and not be one tomorrow, and the record of who made it should not quietly outlive the role that let them.

**Starting a group is not a membership question and has no row.** Any signed-in user may create a group and becomes its `owner` in the same request, because there is no group to belong to yet; `GroupPolicy` skips both pre-checks for `index?`, `new?` and `create?` for exactly that reason. Listing groups is the other half of it: every signed-in user may ask, and `GroupPolicy`'s scope answers with the groups they are a member of, so the tables below decide what a member may do with a group rather than which groups they can see at all.

### Group

| Capability                                             | member | owner | administrator | events_administrator | members_administrator |
|--------------------------------------------------------|:------:|:-----:|:-------------:|:--------------------:|:---------------------:|
| See the group and its details                          |   x    |   x   |       x       |          x           |           x           |
| See the addresses the group and its events point at    |   x    |   x   |       x       |          x           |           x           |
| Edit the group's name, type and description            |        |   x   |               |                      |                       |
| Set or correct the group's home address                |        |   x   |               |                      |                       |
| Delete the group and everything in it                  |        |   x   |               |                      |                       |

### Members

| Capability                                             | member | owner | administrator | events_administrator | members_administrator |
|--------------------------------------------------------|:------:|:-----:|:-------------:|:--------------------:|:---------------------:|
| See the member list and each member's details          |   x    |   x   |       x       |          x           |           x           |
| Add a person to the group                              |        |   x   |       x       |                      |           x           |
| Change a member's status                               |        |   x   |       x       |                      |           x           |
| Grant or revoke a member's roles other than owner      |        |   x   |               |                      |                       |
| Remove a member from the group                         |        |   x   |       x       |                      |           x           |
| Make another member an owner                           |        |   x   |               |                      |                       |

### Events

| Capability                                             | member | owner | administrator | events_administrator | members_administrator | manager |
|--------------------------------------------------------|:------:|:-----:|:-------------:|:--------------------:|:---------------------:|:-------:|
| See the group's events and each event's details        |   x    |   x   |       x       |          x           |           x           |    x    |
| See who is registered for an event, and their answers  |   x    |   x   |       x       |          x           |           x           |    x    |
| Create an event, including duplicating an existing one |        |   x   |       x       |          x           |                       |         |
| Edit an event, including its status and location       |        |   x   |       x       |          x           |                       |    x    |
| Delete an event                                        |        |   x   |       x       |          x           |                       |         |
| Set or change their own attendance answer              |   x    |   x   |       x       |          x           |           x           |    x    |
| Register another member for an event, or invite them   |        |   x   |       x       |          x           |                       |    x    |
| Change another member's attendance answer              |        |   x   |       x       |          x           |                       |         |
| Remove another member's registration                   |        |   x   |       x       |          x           |                       |         |

**Where each column's authority lives.** For the four role columns it is `Role::NAMES`, which holds the vocabulary, and `Role#grants?`, which decides how a role name answers a module question; a role column that is not in `Role::NAMES` is a bug in these tables. For `member` it is `ApplicationPolicy`'s two pre-checks, and for `manager` it is `events.manager_id`, neither of which consults a role row at all.

Nothing enforces the cells yet. #96 and #173 write one example per marked cell, named after the capability rather than the controller action, which is what stops the tables and the code drifting apart. Until they land, every mark is a specification and none of it is enforced.

**Correcting an address has no row of its own.** An address has no permissions and asks whichever group or event points at it: read one you may read the owner of, change one you may change the owner of. So `AddressPolicy` skips the shared pre-checks, and the group's home address row and the event edit row already decide it between them.

**A manager invites and does not un-invite.** `manager` is marked for registering another member for their event and is deliberately not marked for changing that member's answer or removing their registration. Filling an event is the manager's job; overruling somebody's own answer, or taking a registration away once it exists, stays with the group's administrators and its events administrators, and a mistaken invitation is undone by one of them rather than by the person who made it.

**Editing an event includes handing it on.** `events.manager_id` is an attribute of the event like its status and its location, so the edit row decides it and no separate row exists: a manager may pass their event to another member or take one on, and the same three roles may reassign it over their head.

**A capability appears once, at the grain the mechanism can enforce.** `duplicate` authorizes `create?`, so it shares the create row rather than getting its own; an event's status and location are ordinary attributes of an update, so they share the edit row. Splitting either into its own row would allow two marks that no rule can tell apart.

## Records that have no group at all

Two things in this application sit outside the group axis entirely, and neither takes a row above, because a role can never be the answer.

**A user account and its profile belong to the acting user and to nobody else.** `UserProfilePolicy` skips both pre-checks and answers `record.user_id == user.id`, with `edit?` and `update?` aliased to `show?`, so the same identity test decides reading and writing. No group, no role, and no member of any group can reach another person's account or profile through the group they share. `UsersController` and `UserProfilesController` both resolve their record from `Current.user` rather than from the URL, so the identity is never taken from a parameter in the first place.

**An address has no permissions of its own**, per the note above: it inherits from whichever group or event points at it.
