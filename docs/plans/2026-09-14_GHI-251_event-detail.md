> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the event detail

## Which frames this is built from

Frames 4c and 4d, the event detail for an owner and for a plain member, and 4l and 4m, the same screen with "Who's coming" open, read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. 4n is the "nobody asked yet" reading the counts already draw through `events/_counts`.

The frames draw a pushed "Event" title, the name with Duplicate and Edit beside it, a status line, the date and time range, the place, "Managed by Ben C. · Created by Alice B.", a card holding "Who's coming" with the four count tags and the reader's own answer row, and the notes. Opening "Who's coming" unfolds "Who's invited" in place: a tally, the paused members left out, one row per registration, and "Add someone" beneath.

## What the screen is today

`events/show.html.erb` is the scaffold: an "Showing event" heading, `render @event`, and Edit, Duplicate, Back and the confirm sheet's Delete for every reader, whatever the policy says. `events/_event.html.erb` is one run of text through `event_schedule`, its only caller. #252 removed the registration list and the link to it, so nothing on `main` shows who is registered for an event.

## Who sees which control

Each control is gated on the rule its action authorizes, so the screen cannot offer what the submission would refuse: Duplicate on `EventPolicy#create?`, which `EventsController#duplicate` asks; Edit on `edit?`; Delete on `destroy?`.

The roster's two capabilities belong to the reader rather than to a row, so each is asked once against an unsaved registration with no member on it, the record `RegistrationsController#new` already asks: `RegistrationPolicy#create?` there is the invitation row of the events table, the three roles and the event's manager, and decides "Add someone"; `update?` there has `own?` false, so it is `can_manage?(:events)` alone, the "change another member's answer" row, and decides the pills and the take-off on every row. Asking `update?` per row instead would hand a plain member controls on their own row through `own?`, which the fourth criterion rules out, and it would re-run the membership lookup once per row. The probe is `Registration.new(event: @event)`, never `@event.registrations.new`: the second joins the loaded association, which `events/_counts` sizes, and the first was read staying out of it.

The pills post to `registrations#update` and the take-off is a plain `button_to` with `method: :delete` to `registrations#destroy`, both existing actions that authorize the same rules again. The confirm sheet is #264's for deleting a group, an event or a member, and a registration is none of those.

`RegistrationPolicy`'s `relation_scope` stays uncalled: after `authorize! @event` the event's registrations are all in the reader's group, so `authorized_scope` would filter nothing.

## The disclosure

A `<details>` element, per the issue, and the card reads in the frames' order: the counts, the reader's own answer row, then the roster unfolding below both. Everything after `<summary>` folds with it, and the answer row must show while the roster is folded and cannot live inside a `<summary>`, so the `<details>` holds its summary alone - "Who's coming" and `events/_counts` - and the roster is a later sibling that Tailwind's `peer-open:` variant shows, with `aria-controls` on the summary naming it. The counts' `div` inside `<summary>` is block content in phrasing content, which Herb's linter was run against and passes; the daisyUI component syntax expert settles the markup around it.

When `events/_counts` draws "Nobody asked yet" the summary carries that line, and when it draws nothing the summary is "Who's coming" alone: the roster then says nobody is on the list, and "Add someone" is still there for a reader allowed it, since an empty event is exactly the one that needs filling.

## The roster

`Event#roster` returns the event's registrations with each member's profile preloaded, grouped by status - yes, maybe, no, invited, reserved - and ordered within each by the name the row draws, case-insensitively. The name lives on `UserProfile`, reached through `user`, so the preload is what keeps the list from costing two queries a row. The sort is in Ruby because `full_name` falls back to the email's local part and no column holds it. A pill press or a take-off redirects back to the event with the roster folded again.

Above the rows: "Who's invited", `RegistrationsHelper#invited_tally` as #252 wrote it for the invitation screen, and the paused members with no registration on this event named as left out. That set is `Member.without_registration_for` narrowed to `paused`, the scope #252 put on `Member` so the two screens ask one rule.

Each row draws the member's name and their status badge from `IconsHelper`, labelled for a screen reader: the legend's `reserved` bookmark is drawn here, on the read-only roster, as its comment already says. For a reader who may change another member's answer the row also carries the Yes, Maybe and No pills, the current one marked as `events/_rsvp` marks it, and a take-off control; an unanswered row keeps its badge beside them, so `reserved` and `invited` stay distinguishable until #258 gives those rows the paper plane.

## The record's facts

`events/_event.html.erb` becomes the detail body `show` renders: the name at `text-record` with Duplicate and Edit as icon buttons in its row, `status_icon` with `event_status_line`, `event_schedule_range`, the place through `address_map_url`, "Managed by … · Created by …", and the notes through `simple_format`. The manager half is left out when the event has none. `event_schedule`, `DATETIME_FORMAT` and their two helper examples go in the same change, since this partial is their last caller.

"First L." has no helper. `UserProfile#short_name` goes beside `full_name` and falls back to it where either name is missing, the way `full_name` falls back to the email, and `Member` delegates it as it delegates `full_name`. The issue's overview spells this line "Manager: · Creator:", its first criterion and the frames "Managed by · Created by"; the criterion's copy is built.

## Steps

- Add `UserProfile#short_name`, delegated on `Member`, with its model examples.
- Add `Event#roster`, and a helper naming the paused members left out, with their model and helper examples.
- Rebuild `events/_event.html.erb` as the detail body, with Duplicate, Edit and the rest of the record's facts, and remove `event_schedule` and `DATETIME_FORMAT` with their examples.
- Add `events/_roster.html.erb`: the heading, the tally, the left-out line, the rows in both variants and "Add someone".
- Rebuild `events/show.html.erb`: the "Event" title through `shared/page_header`, the detail body, the disclosure around the counts and the roster, the answer row after it, and Delete through the confirm sheet for a reader `destroy?` allows.
- Extend the `GET /groups/:group_id/events/:id` examples in `spec/requests/events_spec.rb` for the owner, member and manager variants of the roster and the gated Duplicate, Edit and Delete.
- Add a system spec for the screen: the controls paint, the disclosure opens onto the rows, a pill press and the Edit link land, and the screen has no accessibility violations in either state.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards.

No file under `spec/system` covers this view yet: `spec/system/events_list_spec.rb` only lands on it and `spec/system/confirm_sheet_spec.rb` deletes a group, so the screen gets a file of its own, `spec/system/event_detail_spec.rb`, which is the case `.agents/testing.md` keeps a new file for.

## Verification

- `bin/ci` is green
- `bin/rspec spec/system/event_detail_spec.rb` passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether the roster reads as one list to a person scanning for a name, and whether the owner's rows read as controls rather than clutter at phone width.

## Open questions

None.

## Settled

- Whether the fourth criterion keeps "Invite the rest" and the paper plane, which the issue's own notes give to #258. They move: "Move this to #258 -- update and sync both issues regarding this "Invite the rest"." The criterion now ends at "Add someone", and #258 carries both controls.
- Whether the roster folds again after a pill press or a take-off redirects back to the event. "Fold again."
- Whether the roster is ordered by name alone. "Nope, it should be sorted first by status (YES, MAYBE, NO, INVITED, RESERVED) and then alphabetically."
- Whether the answer row may sit below the disclosure, so the roster unfolds above it. "It should be placed as it is on 4c, 4l, 4d and 4m screens." The roster unfolds below the answer row, as the disclosure section above describes.
