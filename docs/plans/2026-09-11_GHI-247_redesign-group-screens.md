> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the group screens

Implementation plan for [#247](https://github.com/izkreny/groupifico/issues/247). The issue holds the acceptance criteria; this answers how.

## Approach

Two screens, no new routes and no new policy rule. `groups/index` becomes a list of cards built from the reader's own memberships, `groups/show` becomes the group home: the hero card from #246, the reader's answer row inside it, a link into the events list, and a first-run screen when the group has no events. Both screens read what they need from the controller rather than from the view, because the index needs the reader's membership per group and the home needs the reader's membership once, and neither is reachable through `Current.member` on this controller.

Everything the frames draw that another row owns is left alone: `events/_next_up` and `events/_rsvp` are rendered unedited, the pencil beside the group name is the shell's, and the pencil frame 2b draws on the hero card belongs to `_next_up` and is not added.

## The reader's membership, on a controller that has none

`Current.member` answers `nil` on every `GroupsController` action: `GroupScoped` assigns `Current.group` from `params[:group_id]`, and this controller is not nested. Rather than assign `Current.group` here - which would make one screen an exception to a documented contract - both actions look the membership up and hand it to the view.

- `show` assigns `@membership = @group.members.find_by(user: Current.user)`. It cannot be `nil` in practice, because `GroupPolicy`'s membership pre-check 404s a non-member before the action body runs, and `Event#registration_for` tolerates `nil` anyway through its `member&.id`.
- `index` assigns `@memberships`, the reader's own memberships keyed by group id: `Current.user.current_memberships.includes(:roles).index_by(&:group_id)`. That is the same association the layout already loads for the switcher, and it is what carries the `owner` and `paused` tags.

`@groups` stays `authorized_scope(Group.all)`, because `verify_authorized_scoped` requires an `authorized_scope` call on `index` and the scope is what makes the list the reader's own.

## What a card on the index says

`groups/_group` is rewritten as the card frame 2a draws: the name, a role tag, one meta line. It keeps `id="<%= dom_id group %>"`, which `spec/requests/groups_spec.rb` asserts, and takes strict locals `(group:, membership: nil)` so it reads no instance variable, matching the partials #246 added.

The tag is the reader's standing in that group: `owner` when the membership holds the role, `paused` when its status is, nothing otherwise. An administrator gets no tag, because the frame draws none and the tag says what the reader is rather than what they may do.

The meta line is `6 members · next: Tue 2 Sep` or `6 members · nothing scheduled`. Two pieces:

- **The count** is `group.current_members.count`, a new association on `Group` mirroring `User#current_memberships`: `has_many :current_members, -> { where.not(status: :inactive) }`. A member who has left is not one of the group's people, so counting them would make the number disagree with the members list the reader can open. It is a counted query per group rather than a preload, for the reason below.
- **The date** is `group.next_event`, the method #246 restored, formatted by a new `GroupsHelper#next_event_line(group)` that returns `next: Tue 2 Sep` or `nothing scheduled`. The format is `EventsHelper::DATE_FORMAT` without the clock, which `day_and_time` keeps private and is the right thing to keep private: an index line states a day, not an appointment.

Both are one query per group, so the index costs two queries a card. A reader belongs to a handful of groups, and filtering a preloaded `events` collection in Ruby was tried and rejected on #244, so this stays as it is rather than growing a preload that has to re-implement `next_event`'s filter.

The screen's own chrome loses its scaffold: the Show / Edit / Destroy column goes with the card rewrite, and the `h1` "Groups" is replaced by the frame's "Your groups". "New group" stays a `link_to new_group_path`, and stays the screen's `btn-primary` - frame 2a's `btn-secondary btn-block` is styling, which default daisyUI settles, and `spec/system/groups_index_spec.rb` paints that class deliberately.

## What the home shows

`groups/show` is rewritten around one question: does this group have a next event?

**With one**, it renders `events/_next_up` for `@group.next_event` with the reader's registration, then a "See all events" link carrying a trailing `go_to` chevron. The controller preloads what the hero reads - `registrations: { member: :profile }`, the same preload #246 established for a screen that fetches one event - so the counts and the "said yes" line cost no query per answer.

**With none**, it renders the first-run screen from frame 4g: the heading "Nothing in the diary", the sentence "Add your first rehearsal and everyone gets asked whether they're coming." and a "New event" button, with "It's just you in here so far. Invite the others" beneath when the reader is the group's only current member.

The sentence and the button are drawn only for a reader `EventPolicy#create?` admits, asked as `allowed_to?(:create?, @group.events.new)`: a plain member and a paused owner see the heading and nothing to press, which is the epic's rule that a refused control is absent rather than disabled. "Invite the others" has no target - the invite route arrives with #208 - so it is drawn as plain text for now, with the link added by that row.

Frame 2b's "3 invites pending" row is out of scope by the issue's own technical notes and arrives with #208.

## Where "Delete group" goes

The confirm sheet moves off the home, which is the fifth criterion, and lands on `groups/edit`. That file is #248's by the epic's ownership note, so this is a deliberate touch of a file another open row owns: the criterion asks for the control to live on the edit screen, and deleting it here without placing it there would leave a group undeletable until #248 merges. The move is the three-line `render "shared/confirm_sheet"` block unchanged; #248 restyles it and decides its final placement on that screen.

Two specs follow it rather than staying behind:

- `spec/requests/groups_spec.rb`'s "renders the delete as the trigger's own form" moves from `GET /groups/:id` to `GET /groups/:id/edit`.
- `spec/system/confirm_sheet_spec.rb` visits `group_path` to open the sheet in three examples and reaches it through the index's "Show" link in a fourth. Both routes disappear with this change, so those examples retarget to `edit_group_path`. Nothing about what they assert changes.

## Specs

- **`spec/requests/groups_spec.rb`** carries the reader-by-reader assertions, per the duplication rule: the index card's tag and meta line for an owner, a plain member and a paused member; the home's hero for a group with an event and the first-run copy for one without; "New event" present for an owner and absent for a plain member; the "just you" line for a single-member group and absent for a group of two; and the scaffold's three strings gone.
- **`spec/system/groups_index_spec.rb`** is extended, since it already covers this view: that the cards and the tag paint, and that a card leads to its group.
- **`spec/system/group_home_spec.rb`** is new. `group_shell_spec.rb` covers the chrome by its own header's declaration, not this view, and no file covers `groups/show` itself - the same reading that gave #246 a new `events_list_spec.rb`. It asserts that the hero and the first-run screen paint, that "See all events" lands on the events list, and that both states are free of accessibility violations.
- **`spec/helpers/groups_helper_spec.rb`** is new, for `next_event_line` in both its states.
- **`spec/models/group_spec.rb`** gains examples for `current_members`: that it counts an active and a paused member and not an inactive one.

## Steps

- Compose every piece of markup through the daisyUI Blueprint MCP server, loading the local `daisyui-blueprint-mcp` skill first per the epic: setup expert, rules enforcer, component syntax expert for card, badge and the link, then the quality inspector on the finished change.
- Add `Group#current_members` with its examples in `spec/models/group_spec.rb`.
- Add `GroupsHelper#next_event_line` with `spec/helpers/groups_helper_spec.rb`.
- Rewrite `app/views/groups/_group.html.erb` as the index card, with strict locals.
- Rewrite `app/views/groups/index.html.erb` around it, and assign `@memberships` in `GroupsController#index`.
- Rewrite `app/views/groups/show.html.erb` as the group home, and assign `@membership` and the hero's preload in `GroupsController#show`.
- Move the confirm sheet from `groups/show` to `groups/edit`, and retarget the four examples in `spec/system/confirm_sheet_spec.rb` that reach it through the home or the index.
- Extend `spec/requests/groups_spec.rb` with the index and home assertions, moving the delete-form example under the edit describe.
- Extend `spec/system/groups_index_spec.rb`, and add `spec/system/group_home_spec.rb`.

## Verification

- [ ] `bin/ci`

What those gates cannot see: whether the first-run screen reads as an invitation rather than an error, which is the whole point of the copy and no assertion touches it; whether two queries a card is acceptable on a reader with many groups, since the suite's readers have one or two; and whether the index card and the home's hero read as different weights of the same thing, which default daisyUI settles and the frames' own sizes were never decisions about.

Every check is watched failing before it is trusted: the `current_members` examples against a plain `members` association, which counts the member who left; the tag examples against a card that reads the group rather than the reader's membership; the "New event" absence example against the button drawn unconditionally; and the "just you" example against the line drawn for a group of two.

## Open questions

- Frame 2b draws an owner on a group *with* events and shows no "New event" button - the button appears only on the empty group in 4g, where it is the first-run call to action. The third criterion reads "an owner sees both", which that arrangement satisfies through the shell's pencil and the empty state's button. Implemented as the frames draw it. Should the home carry a "New event" control when the group already has events?
- "Invite the others" lands nowhere until #208 routes an invite, so it is drawn as plain text rather than a dead link. Is text for now right, or should it point at the members list as a stand-in?

## Settled

None yet.
