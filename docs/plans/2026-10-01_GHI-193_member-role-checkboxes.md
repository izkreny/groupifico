> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add role checkboxes to the member form (#193)

## Approach

The gap is the view alone. `MembersController` already permits `roles`, turns posted names into `Role` records, refuses a name outside `Role::NAMES`, and asks `MemberPolicy#manage_roles?` whenever the posted set differs from the held one. The request specs already prove each of those, including that a posted `[""]` revokes every role and that an administrator posting a role is refused.

`app/views/members/_form.html.erb` gains a `Roles` fieldset, rendered only when `allowed_to?(:manage_roles?, member)` answers true. Inside it, `form.collection_check_boxes :roles, Role::NAMES, :itself, :humanize, checked: member.roles.map(&:name)` draws one box per name in the vocabulary, so a new name is a new box with no view change. `checked:` is needed because `roles` holds records and the boxes carry names. Rails' default `include_hidden` stays on: its empty `member[roles][]` value is what makes an all-unticked submission post `[""]`, which `role_records` reads as "hold no roles", rather than posting no `roles` key and changing nothing. On a re-rendered form the boxes reflect the posted, unsaved roles, which is what the reader just chose.

**The third criterion collapses into the fourth under #173's rules.** `manage_roles?` is `membership.owner?`, one rule for both role rows of the members table in `docs/AUTHORIZATION.md`, and the owner may grant every name including `owner`. So the roles a reader may grant are either all of `Role::NAMES` or none: the owner sees every box, and everyone else sees no fieldset at all, which is what keeps an administrator from ever seeing an `owner` box. There is no per-role filter to build, and a helper computing "grantable roles" would have one caller and one branch. A paused owner also sees no boxes, because `manage_roles?` is in `ApplicationPolicy::WRITE_RULES` and the status pre-check refuses it. The refusal half of the fourth criterion is already proven by the existing "cannot grant a role", "cannot revoke a role" and "cannot add one carrying a role" request examples, which landed with #173.

**Three sites predicted that every status change would post the member's unchanged roles once this form existed**, and this design makes that false, since a reader who may not grant roles posts no `roles` key at all. They are the comment on `granting_roles?` in `app/controllers/members_controller.rb`, the comment above the administrator context in `spec/requests/members_spec.rb`, and the sentence on `MemberPolicy#manage_roles?` under *Capabilities* in `docs/AUTHORIZATION.md`. Each cites #193 or describes its form, so correcting them is this issue's work rather than a side edit. The set comparison itself stays: it is what lets a form rendered while its reader could grant roles still change a status after they no longer can.

**Styling is plain daisyUI and stops there.** A `fieldset` with a `fieldset-legend`, and a `label` wrapping a `checkbox` per role. #249 restyles these screens through the daisyUI Blueprint MCP server and adds the Stimulus greying of implied roles, and is blocked by this issue so that it restyles a finished form; neither belongs here.

## Steps

- Render the `Roles` fieldset in `app/views/members/_form.html.erb` for a reader `allowed_to?(:manage_roles?, member)`, one `checkbox` per `Role::NAMES` entry, labelled with the humanized name and checked from the names the member holds
- Extend `spec/requests/members_spec.rb`: an owner on edit sees the four boxes by literal name with the held one checked and the rest unchecked; an owner on new sees all four unchecked; an administrator and a members administrator see no `member[roles][]` input on edit, and a members administrator none on new; each watched failing before the view change
- Extend `spec/system/member_edit_page_spec.rb`: an owner unticks every box on a member holding two roles, submits, lands on the member page, and the member holds no roles; the owner's edit page with its boxes has no accessibility violations; the untick example watched failing once with `include_hidden: false` on the collection, which posts no `roles` key and leaves both roles in place
- Correct the `granting_roles?` comment, the request-spec comment above the administrator context, and the `manage_roles?` sentence in `docs/AUTHORIZATION.md` to say that only a reader who may grant roles posts them, and that the set comparison covers a form whose reader lost that right between render and submit; commit as `docs`
- Run `bin/ci` in this worktree

## Verification

- `bin/rspec spec/requests/members_spec.rb` passes, and each new example was watched failing once before the view change
- `bin/rspec spec/system/member_edit_page_spec.rb` passes, or is red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land; each new example was watched failing once
- `bin/ci` is green, or red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-01_GHI-193_member-role-checkboxes.md docs/AUTHORIZATION.md` exits 0

The browser suite reports nowhere, so the `bin/ci` box is its only gate. What no gate here can see: whether the humanized labels read well to an owner, which #249's restyle revisits anyway.

## Open questions

None.

## Settled

- Does the issue's "`bin/ci` is green" criterion admit the light-theme `.validator-hint` contrast failure that is red on `main`? Yes. The criterion was amended to the wording the owner approved on #249 after the same stop on #313, since `spec/system/member_edit_page_spec.rb`'s existing rejected-submission example reproduces the failure on this branch before any change.
