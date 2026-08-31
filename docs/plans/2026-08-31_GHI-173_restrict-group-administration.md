> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: restrict administration by role (#173 and #96)

Both issues mirror the capability tables in `docs/AUTHORIZATION.md`, one example per marked cell, and neither re-decides a mark. They land together because splitting them buys nothing and costs throwaway code, for the reason under `## Settled`.

## Approach

**Rule bodies are unreachable today, so the pre-check moves first.** `ApplicationPolicy#verify_active_membership!` answers `return allow! if membership.active?`, and an `allow!` in a pre-check settles authorization outright: the rule never runs. `ApplicationPolicy`'s own comment says as much about its four false stubs, which exist only so `write_rule?` can tell a write from a read. Writing `GroupPolicy#update? = membership.owner?` on top of that pre-check moves no verdict at all, because every active member is granted before the rule is consulted. So the pre-check becomes deny-only - `inactive` refused as `not_found`, `paused` refused on a write, and otherwise a plain return that lets the rule decide.

**That change lands alone, as the branch's first commit, and the untouched suite is what proves it.** Every policy relying on the pre-check gets explicit rules reproducing exactly today's verdicts in the same commit, and the whole suite must pass at that commit with no spec edited. Green there means the mechanism moved and no verdict did; once later commits start editing specs, that evidence is no longer available at any price.

**The mechanism gap is one predicate.** #173 describes it as needing a way to tell `owner` from `administrator` *and* a group-level question no module name covers. Both are the same predicate. `Member#can_manage?(:members)` already matches exactly the three roles the member rows mark, and `can_manage?(:events)` matches the three the events rows mark, because `Role#grants?` answers true for `owner`, `administrator` and `#{module}_administrator`. Every remaining marked cell in either table is `owner` alone, and a `:group` module name cannot express it: `grants?` admits `administrator` for *any* module, so `can_manage?(:group)` would be true for an administrator, which is the opposite of what the group rows say. `Member#owner?` is the whole gap; `can_manage?` is unchanged; no policy reads a role row directly.

**`manager` and `creator` are per-record and never roles.** The manager rule asks `events.manager_id` against the acting membership and reaches one event; the creator rule does not exist, because `events.creator_id` grants nothing and the spec that proves it is a refusal. `RegistrationPolicy` asks the same two questions one level down, through `record.event`.

**Refusing an administrator a role grant refuses the whole request rather than dropping the field.** `MembersController` already refuses a role name outside the vocabulary rather than dropping it, because a dropped `roles` key reads as "hold no roles" and silently revokes. Action Policy's field-level answer, `params_filter`, drops. So the controller asks a second question - `manage_roles?` - on `create` and `update` alike, and it asks it when the posted roles **differ from the ones the member holds**, never merely when a `roles` key is present. Key-presence would work today, because `app/views/members/_form.html.erb` posts `status` alone, and would break on the very next issue: #193 adds role checkboxes to that form, after which every status change posts the member's unchanged roles alongside it and an administrator would be refused their own row. Comparing the sets asks the real question - is a role being granted or revoked - and on `create` it degenerates to the right thing by itself, since a member who does not exist yet holds none.

**The last-owner rule lands in the model, not a policy.** A group must not be left ownerless whoever is asking, the last owner acting on themselves included, which is a domain invariant rather than an authorization question; a policy answering it would tell the most privileged member in the group that they are not allowed. It costs one association change: `has_many :roles, dependent: :delete_all` skips callbacks by definition, so a guard on `Role` would be dead code under it, and the `delete_all` precondition - no callbacks needed - stops holding the moment the guard exists.

**#96's warning-before-destroy criterion is already met.** Every destroy button in the application carries `data: { turbo_confirm: "Are you sure?" }`, events and registrations included. It is verified and ticked here rather than implemented.

## Deliberately out of scope

**Hiding the links.** No view calls `allowed_to?`, so after this branch an ordinary member still sees an Edit button that refuses them. That is frontend work for the `main` worktree and deserves its own issue rather than a silent addition here.

**`AddressPolicy` needs no change.** It composes `allowed_to?(:update?, owner)` against whichever group or event points at the address, so both the group's home-address row and the event's location tighten by themselves the moment `GroupPolicy#update?` and `EventPolicy#update?` do. Its request spec's actors change; its code does not.

**Soft deletion**, per #96, and **what happens to a creator or manager who leaves**, per #143.

## Steps

- Convert `ApplicationPolicy#verify_active_membership!` to deny-only so an active member falls through to the rule, add `manage_roles?` to `WRITE_RULES`, and give `GroupPolicy`, `MemberPolicy`, `EventPolicy` and `RegistrationPolicy` explicit rules reproducing today's verdicts - all in one commit, with the suite passing unedited
- Add `Role#owner?` and `Member#owner?`, leaving `can_manage?` untouched
- Tighten `GroupPolicy`: `show?` for every member, `edit?`, `update?` and `destroy?` for the owner alone, with `edit?` composing `update?` through `check?` rather than an alias, so `result.rule` stays a read and a paused owner may still open the form
- Tighten `MemberPolicy`: `show?` for every member, `create?`, `update?` and `destroy?` for `can_manage?(:members)`, and `manage_roles?` for the owner alone
- Authorize `manage_roles?` from `MembersController#create` and `#update` whenever the posted roles differ from the ones the member holds, with a spec proving an administrator may still change a status while posting unchanged roles, which is what #193's form will send
- Tighten `EventPolicy`: `show?` for every member, `create?` and `destroy?` for `can_manage?(:events)`, `update?` for those or the event's own manager, and `edit?` composing `update?` as `GroupPolicy` does
- Tighten `RegistrationPolicy`: `show?` for every member; `create?` and `update?` for every member on their own registration but only towards `yes`, `maybe` or `no`, for `can_manage?(:events)` on anybody's and towards any status, and for the event's manager on `create?` alone; `destroy?` for `can_manage?(:events)` only, since a registration is answered rather than withdrawn
- Flip `Member has_many :roles` to `dependent: :destroy`, and guard the last owner with `Role#before_destroy` for role stripping and `Member#before_destroy` for removal, both standing aside for `destroyed_by_association` so destroying a group still cascades through its last owner
- Add `:owner`, `:administrator`, `:events_administrator` and `:members_administrator` traits to the member factory
- Update the existing specs whose actor is a bare active member and now needs a role: `spec/requests/groups_spec.rb`, `spec/requests/members_spec.rb`, `spec/requests/events_spec.rb`, `spec/requests/registrations_spec.rb`, `spec/requests/addresses_spec.rb`
- Add the new examples, one per marked cell across all three tables, named after the capability rather than the controller action, plus the refusals each criterion names: an ordinary member on every write row, an administrator on each group row, each member-row role on each member row, each events-row role on each events row, the manager permitted on their own event's edit and refused on create, duplicate, destroy, another member's answer and another member's registration, the manager of one event refused on another, and a creator holding no role refused on the event they made
- Add model examples for the last-owner invariant, including a group destroyed whole
- Verify every destroy button already warns, and tick #96's criterion on the issue
- Rewrite `docs/AUTHORIZATION.md` where it calls the tables a specification: all three become record, the note saying the predicate cannot produce them goes, and the sentence promising `403` is corrected to whatever the first open question settles

## Verification

- [ ] The full suite passes at the mechanism commit with no spec file edited in it, which is what "no verdict moved" means concretely
- [ ] `bin/ci` is green
- [ ] `bin/rspec spec/policies spec/models spec/requests` passes with the new examples
- [ ] The docs check passes over `docs/plans/2026-08-31_GHI-173_restrict-group-administration.md`

Every rule here is watched refusing the *permitted* case before the rule is written, for the reason `.agents/testing.md` gives: deny-by-default means a mistyped rule name is a silent denial, so a spec that only ever asserts refusals passes against a policy that refuses everybody. No gate can see whether that was done, and the record of it is prose in the PR rather than a box.

No gate can see whether the specs match the tables either. An example asserting a cell the table leaves blank is green and wrong, so the tables are read against the spec list by hand before the branch goes ready.

## Open questions

None.


## Settled

- **Does a member refused a write get a `403`, or the redirect every other refusal gets?** The redirect. `ApplicationController#deny_access` sends every denial that is not `not_found` to `redirect_to root_path` with an alert, for the reason its comment records: a refused Turbo submission landing back on the form looks like a dead button, and the paused member is refused exactly that way today. So "403 rather than 404" in both issues' criteria and in `docs/AUTHORIZATION.md` reads as "refused plainly rather than concealed", and the sentence promising a status code is corrected in this branch. The rejected alternative was a real `403`, which changes every refusal in the application rather than only these. Settled in the terminal, 2026-08-31.
- **May a member write `reserved` or `invited` onto their own registration?** No. Only `yes`, `maybe` and `no` are an answer, and the table's row is "Set or change their own attendance answer", so a member's own writes are limited to those three; `reserved` and `invited` are the states an administrator, an events administrator or the manager puts somebody into. It is a status check inside `RegistrationPolicy`, not a new cell in the table. Settled in the terminal, 2026-08-31.
- **May a member remove their own registration?** No. A registration is answered, never withdrawn: the options offered are `yes`, `maybe` and `no`, and declining is the `no` answer rather than a deletion. So `RegistrationPolicy#destroy?` mirrors the existing "Remove another member's registration" row unchanged - the three roles, and not the manager - and needs no new cell, which is what the question was asking for. Settled in the terminal, 2026-08-31.
- **Do #96 and #173 land together or in sequence?** Together, on this branch. Whichever went first would have had to pay the pre-check change and hand the other's policies interim rules that grant everything, and those rules are throwaway code that exists only because of a PR boundary: they would let the other table's rows be enforced by a comment for as long as the second branch took. The evidence a separate mechanism PR would have produced is available here from commit ordering instead, per the second paragraph of `## Approach`. The rejected alternatives were #96 first, which is the larger issue and blocks nothing while #173 blocks #193, and a third issue carrying only the mechanism unlock. Settled in the terminal, 2026-08-31.
