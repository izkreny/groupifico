> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: hide actions a member cannot take (#203)

## Approach

**Most of the hiding already exists; this branch proves it and closes the one gap left.** The issue predates the screen redesigns, and #193, #247, #249, #250, #251, #252, #253 and #258 each guarded the controls they drew with `allowed_to?`, asked of the rule the control's action authorizes. Every `button_to` and `link_to` in scope is guarded today: the group pencil in `app/views/layouts/application.html.erb`, the delete sheets on `groups/edit`, `members/edit`, `events/show` and `events/edit`, Invite, the row pencil and the inactive toggle on `members/index`, the pencil on `members/show`, the role fieldset in `members/_form`, New on `events/index` and `groups/show`, Duplicate and Edit in `events/_event`, every roster control in `events/_roster`, the member's own pills in `events/_rsvp`, and Invite everyone in `events/_next_up`. An audit of `spec/requests/` found the request specs cover the owner, a members administrator and a plain member on most controls, and leave the administrator, the events administrator, the manager on the events list, and most paused members unasserted.

**The gap: a paused member is offered an edit form whose Save is certain to be refused.** `edit?` is outside `ApplicationPolicy::WRITE_RULES`, so a paused owner, administrator or manager gets the pencil, opens the form and is refused only at submission. Adding `edit?` to `WRITE_RULES` makes the status pre-check refuse the form itself, which removes every pencil a paused member saw through the existing `allowed_to?(:edit?, …)` calls, and keeps the controller refusing the URL, so the hidden pencil never becomes the only guard. The `members/index` mark for a member who has not signed in yet, and its inactive toggle, are asked of `edit?` too, so a paused members administrator loses both along with the pencils. `AddressPolicy` skips the pre-checks and aliased `edit?` to `show?`, so its form needs its own change: `edit?` aliases `update?` instead, which refuses the form to a paused owner and to any member who may read the address but not correct it.

**Request specs, not view specs.** `.agents/testing.md` already assigns "does this member see this control" to request specs asserting the rendered HTML, and every control here renders on a page a request reaches, so the view-spec carve-out the issue raises is not needed. The one system spec touched is `spec/system/group_refusal_spec.rb`, whose subject is the painted alert and whose trigger moves from submitting the form to opening it.

**Criterion 7 holds by audit rather than by gate.** No view re-derives a rule: the one `membership` predicate a view reads, `membership&.owner?` in `groups/_group.html.erb`, draws a standing badge rather than a control, as that partial's comment says. A grep cannot tell the two apart, so this is stated here instead of gated.

**The group list carries no control for any member**, the owner included, since #247 moved Edit and Delete onto the group's own pages. Criterion 1's group-list half is therefore met by the absence for everybody, and the owner's "still is" half by the header pencil and the edit screen's delete sheet.

## Steps

- `spec/requests/groups_spec.rb`, under "the shell's controls": a plain member gets no group pencil
- `spec/requests/members_spec.rb`: on the list, an owner and an administrator each get Invite, the row pencils and the inactive toggle, and an events administrator gets none of them; on a member's page, an owner and an administrator get the pencil; on the edit screen, an owner and an administrator get Remove; on the new screen, an administrator gets no `member[roles][]` input
- `spec/requests/events_spec.rb`: on the list, an administrator and an events administrator get New, while a members administrator, the manager of an event and a paused events administrator do not; on an event's page, an administrator and an events administrator get Duplicate, Edit and Delete, a members administrator gets none of them, and a paused owner gets neither Duplicate nor Edit; on the roster, an events administrator gets the answer pills for other members, Take off and Add someone, and a members administrator gets none of them; an events administrator gets their own answer pills, and a paused member does not; on the edit screen, an administrator gets Delete
- Watch each new example fail once under a mutation of the guard it rests on, since every one passes on the unchanged tree: the guard replaced with `true` for each absence example and with `false` for each presence example, in `app/views/layouts/application.html.erb`, `app/views/members/index.html.erb`, `app/views/members/show.html.erb`, `app/views/members/edit.html.erb`, `app/views/members/_form.html.erb`, `app/views/events/index.html.erb`, `app/views/events/_event.html.erb`, `app/views/events/show.html.erb`, `app/views/events/edit.html.erb`, `app/views/events/_roster.html.erb` and `app/views/events/_rsvp.html.erb`, each mutation reverted before the next
- Refuse a paused member the edit forms: add `edit?` to `ApplicationPolicy::WRITE_RULES`; turn the examples that granted a paused member an edit form or its pencil into refusals in `spec/requests/groups_spec.rb`, `spec/requests/members_spec.rb`, `spec/requests/events_spec.rb` and `spec/policies/event_policy_spec.rb`, each watched failing before the policy changes; move `spec/system/group_refusal_spec.rb` to opening the form; correct the comments and the `docs/AUTHORIZATION.md` sentences that call opening a form a read
- Refuse the address edit form to a member who may not correct the address: alias `AddressPolicy#edit?` to `update?`, with `spec/requests/addresses_spec.rb` and `spec/policies/address_policy_spec.rb` watched failing first
- Run `bin/ci` in this worktree

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-08_GHI-203_hide-actions.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-08_GHI-203_hide-actions.md docs/AUTHORIZATION.md` exits 0
- `bin/rspec spec/requests/groups_spec.rb spec/requests/members_spec.rb spec/requests/events_spec.rb spec/requests/addresses_spec.rb spec/policies` passes, and each new or changed example was watched failing once
- `git diff main -- spec/requests | grep -E '^-.*(redirect_to root_path|:not_found)'` finds nothing, having found the line when one such assertion was deleted
- `bin/ci` is green

The `git diff` gate is criterion 8 as a check: no refusal assertion that `main` carries is removed, so every refusal example stays. `grep` exits 1 when it finds nothing, so that box is ticked on exit 1 and an exit 0 is the failure. What no gate sees is whether a hidden control reads as missing to a member who expected it, which is a design judgement on the screens rather than an assertion.

## Open questions

None.

## Settled

- Does a paused member keep the edit forms, Save included, because opening a form is a read? No. The owner ruled on the plan thread that offering a form only to refuse its Save is what this issue exists to remove, so `edit?` joins `ApplicationPolicy::WRITE_RULES` and the status pre-check refuses the form itself.
- Does the address edit form, which skips the pre-checks, belong to this branch too? Yes, on the owner's order in the same thread: `AddressPolicy#edit?` aliases `update?`, so the form is refused to whoever its Save would refuse.
