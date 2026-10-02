> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Invite all active members to an event

Implementation plan for [#258](https://github.com/izkreny/groupifico/issues/258). The acceptance criteria live on the issue; this file answers how. The frames are 4e, 4f, 4l and 4n.

## What already exists

`Member.without_registration_for(event)` answers who has no registration, and `RegistrationsController#invitees` already pairs it with `active`. `Event#invite(members)` creates `invited` registrations one by one for the invitation screen, and stays as it is: it serves a hand-picked set and its controller rescues the race row by row.

The roster's tally, its paused line and its badges are #251's, and `events/_counts` already draws "Nobody asked yet · N on the list" on an event whose every registration is `reserved`, so frame 4n needs only its button.

## The approach

**Two model methods, not the one the issue's technical note names.** Criteria 1 and 3 forbid touching an existing registration, and criterion 2 is nothing but moving existing `reserved` ones to `invited`, so one method cannot serve all three:

- `Event#invite_all_active_members` inserts an `invited` registration for every active member without one, in one `insert_all`. Its default skip on conflict, against the unique index on `member_id` and `event_id`, absorbs a row landing mid-request, so no caller needs the rescue `RegistrationsController#create` carries. It serves the form checkbox and "Invite the rest".
- `Event#invite_reserved` moves every `reserved` registration to `invited` in one `update_all`, timestamp included. It serves "Invite everyone".

**Every control is the invitation row, `RegistrationPolicy#create?`, asked of `Registration.new(event:)`** exactly as the roster already asks it. That row marks the manager, where `update?` does not, so the row's plane cannot post to `RegistrationsController#update`: a manager would be refused a control the criteria give them. `docs/AUTHORIZATION.md` gains a sentence saying that moving `reserved` to `invited` is inviting, not changing an answer.

**Routes are nested singular resources rather than custom actions**: `Events::InvitationsController` (new) under each event, `create` for "Invite the rest" and `update` for "Invite everyone", and `Registrations::InvitationsController` (new) under each registration, `create` for the row's plane. The plane moves a `reserved` registration to `invited` and leaves any other status untouched, an answer included, because posting there must not let a manager overrule an answer.

**The form checkbox is `Event#invite_active_members`, a boolean virtual attribute**, permitted in `event_params`. The controller authorizes the invitation row against the event as loaded, before the save, so a `manager_id` changed in the same request cannot decide it, then calls `invite_all_active_members` after a successful save. The checkbox is drawn only for a reader that row admits. "Reserve place for all active members" is the frames' proposal and is not built.

**Visibility.** "Invite everyone" shows on the Next up card when the event has at least one registration and every one is `reserved`, since an empty event satisfies "every" while having nobody to move. "Invite the rest" shows beside "Add someone" only while some active member has no registration. On a `reserved` or `invited` row the plane takes the badge's place for a reader the invitation row admits; plain for `reserved`, tinted for `invited`.

Markup goes through the daisyUI Blueprint MCP server, with the local `daisyui-blueprint-mcp` skill loaded first, per the epic; default daisyUI wins on styling.

## Steps

- `app/models/event.rb`: `invite_all_active_members`, `invite_reserved` and the `invite_active_members` attribute, with examples in `spec/models/event_spec.rb` asserting through `Registration` status scopes: only active members, existing registrations untouched, paused and inactive members left out, and `reserved` moved while answers stay
- `config/routes.rb`, `app/controllers/events/invitations_controller.rb` (new) and `app/controllers/registrations/invitations_controller.rb` (new), with `spec/requests/events/invitations_spec.rb` (new) and `spec/requests/registrations/invitations_spec.rb` (new) covering each role column, the manager, a paused member, a non-member, the signed-out redirect, and an answered row left as it was
- `app/controllers/events_controller.rb` and `app/views/events/_form.html.erb`: the checkbox, with examples in `spec/requests/events_spec.rb` for create and update with it ticked, unticked, and its absence for a reader the invitation row refuses
- `app/views/events/_next_up.html.erb` and `app/views/events/_roster.html.erb`: "Invite everyone", "Invite the rest" and the row planes, with request examples in `spec/requests/events_spec.rb` for who sees each control
- `docs/AUTHORIZATION.md`: the sentence on inviting a `reserved` registration
- `spec/system/event_detail_spec.rb`, `spec/system/events_list_spec.rb` and `spec/system/event_form_spec.rb`: each new control paints and its navigation lands, with no accessibility violations

## Verification

- `bin/rspec spec/models/event_spec.rb` passes
- `bin/rspec spec/requests/events_spec.rb spec/requests/events/invitations_spec.rb spec/requests/registrations/invitations_spec.rb` passes
- `bin/rspec spec/system/event_detail_spec.rb` passes
- `bin/rspec spec/system/events_list_spec.rb` passes
- `bin/rspec spec/system/event_form_spec.rb` passes
- `bin/ci` is green

The gates cannot see whether an owner reads the tinted plane as "already asked" rather than as a pressed toggle; that is the owner's to judge on the screen.

## Open questions

- **Routing.** The issue's note says "a member route on events", and `get "duplicate", on: :member` is the precedent for that reading. This plan builds nested singular `invitation` resources instead, the house style's resource-per-action, and the row's plane needs one under registrations either way; the alternative is `post :invite_all` and `patch :invite_reserved` on the event's member routes.
