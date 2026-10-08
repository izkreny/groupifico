> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: hide actions a member cannot take (#203)

## Approach

**The hiding already exists; this branch proves it.** The issue predates the screen redesigns, and #193, #247, #249, #250, #251, #252, #253 and #258 each guarded the controls they drew with `allowed_to?`, asked of the rule the control's action authorizes. Every `button_to` and `link_to` in scope is guarded today: the group pencil in `app/views/layouts/application.html.erb`, the delete sheets on `groups/edit`, `members/edit`, `events/show` and `events/edit`, Invite, the row pencil and the inactive toggle on `members/index`, the pencil on `members/show`, the role fieldset in `members/_form`, New on `events/index` and `groups/show`, Duplicate and Edit in `events/_event`, every roster control in `events/_roster`, the reader's own pills in `events/_rsvp`, and Invite everyone in `events/_next_up`. What the issue still lacks is evidence: an audit of `spec/requests/` found the request specs cover the owner, a members administrator and a plain member on most controls, and leave the administrator, the events administrator, the manager on the events list, and most paused readers unasserted.

**Request specs, not view specs.** `.agents/testing.md` already assigns "does this reader see this control" to request specs asserting the rendered HTML, and every control here renders on a page a request reaches, so the view-spec carve-out the issue raises is not needed. No system spec changes either: whether a control is present for a reader is the request layer's assertion, and the browser adds nothing to it.

**Criterion 7 holds by audit rather than by gate.** No view re-derives a rule: the one `membership` predicate a view reads, `membership&.owner?` in `groups/_group.html.erb`, draws a standing badge rather than a control, as that partial's comment says. A grep cannot tell the two apart, so this is stated here instead of gated.

**A paused reader keeps the edit forms, Save button included.** `edit?` is a read under `ApplicationPolicy::WRITE_RULES`, so a paused owner or manager still gets the pencil and the form and is stopped at the submission, which `spec/requests/groups_spec.rb` ("stopped at the submission"), the paused events administrator's edit example and `spec/system/group_refusal_spec.rb` pin today. Hiding Save would turn those red, which criterion 8 rules out, so the paused examples below assert that the pencil stays and every write control off a form goes.

**The group list carries no control for any reader**, the owner included, since #247 moved Edit and Delete onto the group's own pages. Criterion 1's group-list half is therefore met by the absence for everybody, and the owner's "still is" half by the header pencil and the edit screen's delete sheet.

## Steps

- `spec/requests/groups_spec.rb`, under "the shell's controls": a plain member gets no group pencil; a paused owner keeps it
- `spec/requests/members_spec.rb`: on the list, an owner and an administrator each get Invite, the row pencils and the inactive toggle, an events administrator gets none of them, and a paused members administrator keeps the row pencils; on a member's page, an owner and an administrator get the pencil; on the edit screen, an owner and an administrator get Remove; on the new screen, an administrator gets no `member[roles][]` input
- `spec/requests/events_spec.rb`: on the list, an administrator and an events administrator get New, while a members administrator, the manager of an event and a paused events administrator do not; on an event's page, an administrator and an events administrator get Duplicate, Edit and Delete, a members administrator gets none of them, and a paused owner keeps Edit and loses Duplicate; on the roster, an events administrator gets the answer pills for other members, Take off and Add someone, and a members administrator gets none of them; an events administrator who is invited gets their own answer pills, and a paused member who is invited does not; on the edit screen, an administrator gets Delete
- Watch each new example fail once under a mutation of the guard it rests on, since every one passes on the unchanged tree: the guard replaced with `true` for each absence example and with `false` for each presence example, in `app/views/layouts/application.html.erb`, `app/views/members/index.html.erb`, `app/views/members/show.html.erb`, `app/views/members/edit.html.erb`, `app/views/members/_form.html.erb`, `app/views/events/index.html.erb`, `app/views/events/_event.html.erb`, `app/views/events/show.html.erb`, `app/views/events/edit.html.erb`, `app/views/events/_roster.html.erb` and `app/views/events/_rsvp.html.erb`, each mutation reverted before the next
- Run `bin/ci` in this worktree

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-08_GHI-203_hide-actions.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-08_GHI-203_hide-actions.md` exits 0
- `bin/rspec spec/requests/groups_spec.rb spec/requests/members_spec.rb spec/requests/events_spec.rb` passes, and each new example was watched failing once under its mutation
- `test "$(git diff --numstat main -- spec/requests | awk '{ s += $2 } END { print s + 0 }')" -eq 0` exits 0, having exited 1 with one existing line deleted
- `bin/ci` is green

The `git diff` gate is criterion 8 as a number: no existing request-spec line is deleted or changed, so every refusal example stays as it was. What no gate sees is whether a hidden control reads as missing to a member who expected it, which is a design judgement on the screens rather than an assertion.

## Open questions

None.

## Settled

None yet.
