> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Authorization

Who may do what inside a group, and why the code answers it the way it does. The mechanism is Action Policy, adopted in [ADR 0003](adr/2026-08-25_authorization-with-action-policy_0003.md); this document is the model that sits on top of it.

## Specification, or record?

Both, and which half you are reading decides who wins a disagreement.

**The capability tables are a specification, and they are the authority.** They decide who may do what, and the code is obliged to implement them: where a rule and a cell disagree, the rule is the bug. What makes that more than a wish is that every rule carries an example per role column, so a verdict that moves without the table moving turns a spec red.

**Everything else is a record of the code, and there the code wins.** The two questions below, the status filter that answers the second, and everything in `## Records that have no group at all` describe how the application behaves, so where they and the code disagree, this document is the bug.

Two facts about the mechanism are worth knowing before reading any rule, and both belong to that second half: `ApplicationPolicy`'s status pre-check refuses and never grants, so a policy's own rule is what decides; and `ActionPolicy::Base` denies any rule a policy does not define, so a capability nobody wrote is refused rather than raised.

## Two questions, in order

Every request inside a group asks these, in this order, and the second one is a status question rather than a role one.

1. **Does the acting user belong to this group?** No `Member` row means the record does not exist for them: `404`, not `403`, so the response does not confirm the id exists. `ApplicationPolicy#verify_membership!` is the authority, and [ADR 0003](adr/2026-08-25_authorization-with-action-policy_0003.md) records why the refusal is a `404` rather than a `403` and what that choice is worth. The reasoning lives there and is deliberately not copied here.
2. **What does their status permit?** `inactive` has left and is refused exactly like a non-member, with the same `404`. `paused` still belongs and keeps every read row below, losing every other row. `active` is the only status where the tables are consulted in full. `ApplicationPolicy#verify_active_membership!` is the authority, and `ApplicationPolicy::WRITE_RULES` is what it counts as a write.

Status is orthogonal to role, which is why it is stated here once instead of as three more columns: multiplying the two axes would make two thirds of the cells duplicates of each other.

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

**Where each column's authority lives.** For the role columns it is `Role::NAMES`, which holds the vocabulary, and two predicates on `Member`: `can_manage?`, which asks `Role#grants?` how a role name answers a module question, and `owner?`, which asks `Role#owner?`. A role column that is not in `Role::NAMES` is a bug in these tables. For `member` it is `ApplicationPolicy`'s two pre-checks, and for `manager` it is `events.manager_id`, neither of which consults a role row at all.

**Two predicates, because one cannot say this much.** `Role#grants?` answers true for every module question on both `owner` and `administrator`, so `can_manage?` cannot tell the two apart and no module name expresses a row given to `owner` alone - `can_manage?(:group)` would admit an administrator, which is the opposite of what the group rows say. `Member#owner?` is what those rows ask. Everything else is `can_manage?`: the member rows are `can_manage?(:members)`, which matches `owner`, `administrator` and `members_administrator` exactly, and the events rows are `can_manage?(:events)`.

Every rule the tables decide carries an example per role column in `spec/policies/`, named after the capability rather than the controller action: `succeed` where the row marks the column and `failed` where it leaves it blank. That is what stops the tables and the code drifting apart, and the refusals are as load-bearing as the grants, because `ActionPolicy::Base` answers a misspelled rule name with a denial that looks exactly like a considered one - so a rule proven only by its grants and one proven only by its denials are both unproven.

Two rows have no rule of their own and are proven where they are decided rather than where they are written: the group's home address, which `AddressPolicy` inherits from `GroupPolicy#update?`, and duplicating an event, which authorizes `EventPolicy#create?` and shares its examples.

**Two capabilities are not controller actions and are asked as a second question.** `MemberPolicy#manage_roles?` decides the two role rows, and `MembersController` asks it whenever the posted roles differ from the ones the member holds - the set rather than the key's presence, so an administrator changing a status while the form posts unchanged roles keeps their own row. `RegistrationPolicy#manage_answers?` decides which statuses the actor may write, and `RegistrationsController` asks it whenever the posted status is not one a member says about themselves, because a posted status is not on the record when `update?` runs.

**No capability can leave a group without an active owner.** The members table lets three columns remove a member, gives the owner alone the revoking of a role, and lets three columns change a status, and all three moves stop short of the last active owner: a group always has one. **An owner is an active owner**, because a `paused` one is refused every write by the status pre-check - including the write that would restore them - and an `inactive` one has left, so counting either would let the last member who can actually act be removed while the group still looked owned.

That is a domain invariant rather than an authorization rule - it refuses the last owner acting on themselves, and a policy answering that would be telling the group's most privileged member they are not allowed. It lives on the models: a `before_destroy` guard on `Member` and on `Role` for the two destructions, and a validation on `Member` for the status write, which is an ordinary update and has a form to render the message on. Destroying the group itself still cascades through its last owner, because a group on its way out needs no owner.

**A member who belongs but lacks the role is refused plainly rather than concealed.** That is the split ADR 0003 records: a non-member is told nothing and gets the `404`, while somebody who can already see the group in the interface is told they may not, because concealment from them is noise rather than security. Concretely the refusal is the redirect with an alert that `ApplicationController#deny_access` gives every denial that is not `not_found`, rather than a bare `403` status - a refused Turbo submission that lands back on its own form is indistinguishable from a dead button. So the distinction is in what the response says, not in its status code.

**Correcting an address has no row of its own.** An address has no permissions and asks whichever group or event points at it: read one you may read the owner of, change one you may change the owner of. So `AddressPolicy` skips the shared pre-checks, and the group's home address row and the event edit row already decide it between them.

**A registration is answered, never withdrawn.** The statuses are `reserved`, `invited`, `yes`, `maybe` and `no`, and only the last three are an answer, so a member's own writes are limited to those three: `reserved` and `invited` are what somebody filling the event puts you into. Declining is the `no` answer rather than a deletion, which is why no row grants a member the removal of their own registration and `RegistrationPolicy#destroy?` is the three roles' alone.

**A manager invites and does not un-invite.** `manager` is marked for registering another member for their event and is deliberately not marked for changing that member's answer or removing their registration. Filling an event is the manager's job; overruling somebody's own answer, or taking a registration away once it exists, stays with the group's administrators and its events administrators, and a mistaken invitation is undone by one of them rather than by the person who made it.

**Editing an event includes handing it on.** `events.manager_id` is an attribute of the event like its status and its location, so the edit row decides it and no separate row exists: a manager may pass their event to another member or take one on, and the same three roles may reassign it over their head.

**A capability appears once, at the grain the mechanism can enforce.** `duplicate` authorizes `create?`, so it shares the create row rather than getting its own; an event's status and location are ordinary attributes of an update, so they share the edit row. Splitting either into its own row would allow two marks that no rule can tell apart.

## Records that have no group at all

Two things in this application sit outside the group axis entirely, and neither takes a row above, because a role can never be the answer.

**A user account and its profile belong to the acting user and to nobody else.** `UserProfilePolicy` skips both pre-checks and answers `record.user_id == user.id`, with `edit?` and `update?` aliased to `show?`, so the same identity test decides reading and writing. No group, no role, and no member of any group can reach another person's account or profile through the group they share. `UsersController` and `UserProfilesController` both resolve their record from `Current.user` rather than from the URL, so the identity is never taken from a parameter in the first place.

**An address has no permissions of its own**, per the note above: it inherits from whichever group or event points at it.
