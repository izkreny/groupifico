> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the member screens (#249)

## Which frames this is built from

Frames 3a and 3b (the roster, read by an owner and by a plain member), 3c (the detail) and 3d (the edit), read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. The issue outranks a frame where the two differ. 3a's "3 invites pending" and frames 3e and 3f are #208's, which drew the pending state as the "not signed in yet" badge on a row; that badge stays as #208 built it.

## What the screens are today

`members/index`, `members/show` and `members/edit` are the scaffold's: an `h1`, `members/_member` printing the name and the status, and ghost Show, Edit and Destroy buttons on every row for every reader. The index lists every status in id order, under a `TODO` asking for active and paused by default. The remove confirmation sits on `show`, and `members/_form` draws the status as a `select` and the roles as plain checkboxes, which #193 left for this issue to restyle.

## The roster

The shell's header already carries the group's name, so the tab screen has no page header of its own, as on the events list. A reader who may add members, asked once as `allowed_to?(:create?, Member.new(group: @group))`, sees "N members" and an Invite button with the `:new` icon, as 3a draws it, leading to `new_group_member_path`; a plain member sees neither. N counts the current members, active and paused, whatever the toggle says, since an inactive member has left.

Each member is a `list-row` with an `avatar avatar-placeholder` holding `UserProfile#initials`, the name linking to the member's detail, and one `badge` per role held, in `Role::NAMES` order, reading the display names `owner`, `admin`, `events admin` and `members admin`. A paused member's row is dimmed and carries a `paused` badge. Call and Email are icon buttons with `phone_to` and `mail_to`, labelled "Call {name}" and "Email {name}", Call only where the member has a mobile. An Edit pencil follows for a reader `allowed_to?(:edit?, ...)` admits, asked once before the loop as the index already does for the badge; a plain member sees no pencil, so no row of theirs opens an edit form. The detail link is everyone's, because every column of the members table may see each member's details.

Order is alphabetical by `full_name`, case-insensitive, sorted in Ruby after `includes(:roles, user: :profile)` the way `Event#roster` sorts: `full_name` falls back to the address's local part, so ordering on the profile columns in SQL would misplace a member with no name. The default list is `Member.current`, a new scope spelling `User#current_memberships`' own `where.not(status: :inactive)`, and `?inactive=1` widens it to every status. "Show inactive" and "Hide inactive" toggle that parameter, drawn for the same reader the pencil is, since a plain member gets names, roles and contact links only. The parameter itself is honoured for anyone, because reading an inactive row is still seeing the member list.

## The detail: "Member"

`shared/page_header` with "Member", then the avatar, the name at `text-record`, the Edit pencil for an `edit?` reader in the name's row as on `events/_event`, and the role badges plus a status badge. Below, Email and Mobile each with their contact button, Mobile only where there is one, and "Joined" with the membership's `created_at` as "14 Mar 2024". Then "Manages", the member's `managed_events` earliest first, each linking to its event with `event_schedule_start` beside it, every event rather than the upcoming ones, since a past event is still one they ran; the section is left out when there are none, as the address's "Used by" is. The remove confirmation leaves this screen for the edit screen.

## The edit: "Edit member"

`shared/page_header` with "Edit member" rather than the member's name, per that partial's own rule. `members/_form` draws the status as `form.segmented_field :status` over active, paused and inactive, and the roles for a reader `manage_roles?` admits as one checkbox per `Role::NAMES`, labelled with the long name and the frame's hint: "everything", "all modules", "events only", "roster only". Cancel and a submit close the form, the submit passed in as `submit:` the way `events/_form` takes it: "Save member" on edit and "Send invite" on new. `members/new` gets the page header "Invite a member" and the same restyle, its fields left as #208 built them.

Remove sits below the form, as on `events/edit`, because the confirm sheet's trigger is a `button_to` and a form cannot hold another. It renders `shared/confirm_sheet` without `word`, the plain variant, gated on `allowed_to?(:destroy?, @member)`. The two refusals already exist: `MembersController#refuse_ownerless_group` answers removing the last owner and unticking their owner role with the alert "A group must always have an owner.", and the request examples asserting both are kept passing.

## Greying implied roles

`Role#implies?(name)` answers whether holding this role already grants the named one: the owner implies every other name, which only `owner?` can say, since `grants?` admits `administrator` for every module, and a module role, recognised by its `_administrator` suffix, is implied wherever `grants?` answers true for its module and the name is not this role's own. The form renders each box's implied names as data, and a Stimulus controller, `app/javascript/controllers/role_implications_controller.js` (new), greys the boxes a ticked broader role implies, and ungreys them when it is unticked.

**Greyed boxes stay enabled and keep their state.** A disabled checkbox is not submitted, so an owner saving a status change on a member holding `administrator` and `events_administrator` would post the first alone, `granting_roles?` would answer true, and the save would destroy a role row nobody touched. Greying is presentation, never a change to what the form posts.

## Dimming and contrast

A paused row and a greyed role both dim enabled text, and axe-core does not fold an ancestor's opacity into a colour, so `be_accessible` cannot hold either up. `ContrastHelper#text_contrast` can, and the system specs assert both against `ContrastHelper::WCAG_AA` in each theme, so the dim level is the strongest one that still passes. If no stock utility does, that is the wireframe-fidelity case to raise rather than a reason to write CSS.

## Steps

- Add `Member.current`, delegate `initials` and `mobile_phone` to the profile, and add `Role#implies?`, with examples in `spec/models/member_spec.rb` and `spec/models/role_spec.rb`.
- Order and filter the index in `MembersController#index` as *The roster* says, replacing the `TODO`.
- Add the role display names, the role choices with their hints, the status choices and the joined date to `app/helpers/members_helper.rb`.
- Rebuild `members/index.html.erb` and `members/_member.html.erb` as *The roster* says.
- Rebuild `members/show.html.erb` as *The detail* says, moving the remove confirmation off it.
- Rebuild `members/edit.html.erb`, `members/new.html.erb` and `members/_form.html.erb` as *The edit* says, with `app/javascript/controllers/role_implications_controller.js` (new) as *Greying implied roles* says.
- Update the request examples in `spec/requests/members_spec.rb` that assert the old markup, keeping `dom_id(member)` and `dom_id(member, :row)` on the rows, and add ones for the order, the default and widened status filter, Invite and the count present and absent by reader, Call only with a mobile, the pencil and the toggle absent for a plain member, the detail's fields and "Manages", the segmented status, the role hints, and Remove on edit only for a `destroy?` reader.
- Extend `spec/system/members_list_spec.rb` with a paused member in the fixture: the badges and the contact buttons paint, the dimmed row keeps `WCAG_AA` contrast in both themes, the name lands on the detail and the pencil on the edit screen.
- Extend `spec/system/member_edit_page_spec.rb`: its rejected-submission context chooses the `inactive` segment instead of selecting it and asserts the segmented error state as `spec/system/group_form_spec.rb` does; ticking owner greys the three narrower boxes, unticking it restores them, and a greyed label keeps `WCAG_AA` contrast; Remove opens the sheet and confirming lands on the roster without the member; the `click_button` calls follow the new submit text, in `spec/system/member_new_page_spec.rb` too.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards.

## Verification

- `bin/rspec spec/models/member_spec.rb spec/models/role_spec.rb spec/requests/members_spec.rb` passes, and each new example was watched failing once before it was trusted
- `bin/rspec spec/system/members_list_spec.rb spec/system/member_edit_page_spec.rb spec/system/member_new_page_spec.rb` passes, or is red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land; each new example was watched failing once
- `bin/ci` is green, or red only on axe's `color-contrast` for `.validator-hint` in the light theme (2.87:1), which fails on `main` too until #257 and #299 land
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-01_GHI-249_member-screens.md` exits 0

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether the greyed boxes read as "already granted" rather than "unavailable" to an owner who has never seen the screen.

## Open questions

None.

## Settled

- Greyed role boxes stay enabled and keep their state, rather than being disabled, because a disabled box is not posted and a status-only save would revoke the role rows it greys.
- "Show inactive" is drawn for a reader who may edit members, as 3a draws it and 3b leaves it out, while the parameter is honoured for anyone, since reading an inactive row is still seeing the member list.
- "N members" counts active and paused members whatever the toggle says.
- "Manages" lists every event the member manages, past ones included, earliest first, and is left out when there are none.
- Dimmed rows and greyed roles use theme colours, never an opacity utility: the theme's `base-content` at 70%, 5.67:1 on light `base-100` and 7.09:1 on dark, since no grey token passes in both. The role labels drop daisyUI's `.label`, whose own 65% tone left no room for a grey above AA.
- The members administrator's hint reads "members only", derived from `Role::NAMES` like every other hint, rather than frame 3d's "roster only".
- The rejected-status example asserts no coloured border, because no segmented field in the app colours one on error.
