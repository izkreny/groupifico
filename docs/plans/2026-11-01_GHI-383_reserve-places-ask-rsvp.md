> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: reserve places and ask for an RSVP (#383)

## The words

Registering reserves a place, asking for an RSVP is a separate later act, and "invite" stays for bringing someone into the group alone. The code takes these names:

| Now | Becomes | Why |
|---|---|---|
| status `invited` | `rsvp_asked` | not `asked`, whose generated predicate would collide with the hand-written `Registration#asked?` |
| `Registration#invite` | `Registration#ask_for_rsvp` | |
| `Event#invite_all_active_members` | `Event#ask_all_active_members_for_rsvp` | |
| `Event#anyone_left_to_invite?` | `Event#anyone_left_to_ask?` | |
| `Event#invite_active_members` | `Event#reserve_active_members` | the form's box, which now reserves |
| `resource :invitation`, twice | `resource :rsvp`, twice | the issue's new noun |
| `Events::InvitationsController`, `Registrations::InvitationsController` | `Events::RsvpsController`, `Registrations::RsvpsController` | |
| `invited_tally` | `list_tally` | it counts places, not questions |
| `ICONS[:invited]` | `ICONS[:rsvp_asked]`, and `ICONS[:send_invite]` for `app/views/members/_form.html.erb` | that form's button is the group-joining sense, so it takes a key of its own on the same glyph |

The rename needs no migration: `Registration`'s enum is declared as an array over an integer column, so `rsvp_asked` keeps index 1 and every stored row keeps its meaning.

What stays: `app/views/members/new.html.erb`, `app/views/members/index.html.erb`, `app/views/members/_form.html.erb`'s "Send invite", `app/views/sessions/new.html.erb`, `app/controllers/sessions_controller.rb`, `app/views/groups/show.html.erb`, the styleguide's "your invitation was sent" alert and ADR 0004, all of which mean joining the group. `app/mailers/member_mailer.rb`'s comment says an invitation is a `Registration` status, so it is rewritten.

## The copy

| Where | Now | Becomes |
|---|---|---|
| roster heading | Who's invited | Who's on the list |
| both tallies | 3 of 5 invited | 3 of 5 on the list |
| paper plane, unasked | Invite Ana | Ask Ana to RSVP |
| paper plane, asked | Ana is invited, no reply yet | Ana was asked to RSVP, no reply yet |
| status label | Invited, no reply yet | Asked to RSVP, no reply yet |
| roster button | Invite the rest | Ask the rest |
| next-up button | Invite everyone | Ask everyone |
| notices | 2 members invited. / Nobody was left to invite. | 2 members asked to RSVP. / Nobody was left to ask. |
| event form box | Invite all active members | Reserve a place for every active member |
| list screen, paused row | paused · can't be invited | paused · can't be added |
| list screen, submit | Invite 2 people | Save |
| list screen, notice | 2 members invited. | 2 places reserved, 1 removed. |
| list screen and its roster button | Add someone | Edit the list |

The frames still say "invited" in these places, and the issue overrides them. The generic Save follows Square's [add or remove screen](https://mobbin.com/screens/8b317877-df63-4b01-a60d-35c69b10d591), where the ticked rows are the current members: a count stops meaning anything once one submit both adds and removes, and the notice says what happened instead.

## The list screen

`RegistrationsController#new` and `#create` become `Events::RostersController#edit` and `#update`, drawn by `app/views/events/rosters/edit.html.erb` (new) in place of `app/views/registrations/new.html.erb` (delete), under `resource :roster, only: %i[ edit update ], module: :events`, because one form both adds and removes and a `create` that deletes is not what the verb says. `RegistrationsController` keeps `update` alone, and `destroy` and its route go with the take-off. The Stimulus controller `app/javascript/controllers/invite_controller.js` (delete) becomes `app/javascript/controllers/list_controller.js` (new), which enables Save once a tick differs from what was drawn and drives the select-all below.

The screen's sections:

- **On the list**: every registered member, ticked, whatever their membership status. A paused or inactive member's registration can only be removed here once the roster loses its take-off, so they have to be drawn.
- **Not on the list**: active members unticked, then paused members with no checkbox, as today.

The form posts `member_ids[]`, the ticks, and a hidden `listed_ids[]`, the rows it drew ticked. Removal is `listed_ids` minus `member_ids`, never "everyone not ticked", so somebody registered while the form sat open is not removed unseen. Reservation stays `@group.members.active.without_registration_for(@event)` intersected with the ticks, which keeps the guard against an id from another group. Both go in one transaction in a new `Event#update_roster`, and the `RecordNotUnique` rescue stays.

Unticking somebody who answered removes the answer with the place, as the take-off does today.

**A manager may reserve and may not remove.** `RegistrationPolicy#create?` admits the event's manager and `#destroy?` does not, per `docs/AUTHORIZATION.md`. So:

- A manager's registered rows draw no checkbox and a line beneath the name saying only an administrator can remove them, and post no `listed_ids`, so nothing on their screen is certain to be refused. That is the screen's own paused row, and [Slack's already-in-this-group row](https://mobbin.com/screens/2028122c-f08f-4f06-b4e5-719053f83b61) draws the same. The section heading is what says they are on the list.
- `Events::RostersController#update` asks `create?` always and `destroy?` whenever the removal set is not empty, of a registration with no member on it, and a refusal stops the whole request before any write. A forged removal is refused, never silently dropped.

The screen goes through the daisyUI Blueprint MCP server, with the `daisyui-blueprint-mcp` skill loaded first, in the `organic` and `organic-dark` themes.

## Reserving everyone

`Event#reserve_all_active_members` gives every active member with no registration a `reserved` one and touches nothing else, so an answer or a held place is never overruled. The new event form's box calls it after the save. The box stays on the edit form too, since `app/views/events/_form.html.erb` is shared, what it does there is equally true, and the issue does not ask for its removal.

The list screen offers the same thing as a select-all checkbox on the "Not on the list" heading, which ticks that section's active rows, and Save commits as for any other tick. Bulk selection on [Revolut Business](https://mobbin.com/screens/e8e96d47-3cdd-417a-8915-51427056f4fe) and [Fresha](https://mobbin.com/screens/536ebd20-c772-49c5-b0e4-b81af044fc10) sits above the rows and changes only the ticks, and no screen found used a separate button that acts at once. Scoped to that section, it can never untick a registered member, so it means the same for a manager. It needs JavaScript and is drawn hidden until the controller connects, so the screen still works one tick at a time without it.

## Asking

`Event#ask_all_active_members_for_rsvp` moves held places only, and `Event#anyone_left_to_ask?` reads held places only. Being off the list is a choice now, so an asking button that also registered would undo every untick. This is an open question, and the plan assumes the recommended answer.

## Decided on the way

- **No `asked_at` column.** #382, the only reader, has no milestone, so the column would have no caller in this branch.
- **`Event#attendees` goes.** Nothing in `app/` reads it. Its shoulda line in `spec/models/event_spec.rb` goes with it, the assertion in `spec/requests/registrations_spec.rb` moves to `event.registrations`, and the comment naming it in the controller is reworded. `app/views/events/show.html.erb` stops saying "attendance card".

## Open questions

- Should Ask the rest also register active members who are off the list? 1. No, it asks held places only, so an untick stays an untick (recommended, assumed here). 2. Yes, as frame 4l's note has it today, so one tap still fills the event and an unticked member comes back with it.
- Should the screen and its roster button stop being called Add someone, now that the roster's take-off is gone and this is the only way to remove anyone? 1. Yes, Edit the list, since [Square](https://mobbin.com/screens/8b317877-df63-4b01-a60d-35c69b10d591) and [1Password](https://mobbin.com/screens/0a4ebde3-a855-4e9b-ad56-2a0d8fc37181) both name the two directions (recommended, assumed here). 2. No, keep Add someone as the issue and frame 9m call it, and removal has to be found by opening it.

## Steps

- `refactor:` rename the status, methods, routes, controllers, helpers and icon keys per "The words", specs included, with every string on screen unchanged and the existing suite passing.
- `feat:` change the copy per "The copy", with the strings the specs read.
- `feat:` make the list screen reserve the ticked members rather than asking them.
- `feat:` draw registered members ticked and remove the unticked, through `Events::RostersController`, with the manager's rows and the `destroy?` refusal.
- `feat:` take the take-off off the roster rows, deleting the specs that read it and adding no example for its absence.
- `feat:` add `Event#reserve_all_active_members` and the event form's box, and the list screen's select-all.
- `feat:` narrow asking to held places.
- `refactor:` remove `Event#attendees` and the "attendance card" wording.
- `docs:` bring `docs/AUTHORIZATION.md` and the README's entity description to the same words, including the manager's paragraph, keeping the capability table's column widths.
- Watch every new example go red per "Seen red".

## Seen red

| New example | What turns it red |
|---|---|
| ticking reserves, asks nobody | `Event#update_roster` writing `rsvp_asked` |
| unticking removes the registration | dropping the removal from `Event#update_roster` |
| a member registered while the form sat open stays | removal computed as everyone not ticked |
| an id from another group is not reserved | unscoping the reservation lookup |
| a manager's posted removal is refused and nothing is written | dropping the `destroy?` check |
| a manager's screen draws no checkbox on a registered row | drawing the checkbox for every row |
| a paused member's registration can be removed | listing active registrations only |
| reserving everyone skips paused members and leaves answers alone | dropping `.active`, and writing over existing rows |
| the select-all ticks every active off-list row and no paused or registered one | the Stimulus controller ticking every checkbox |
| the select-all is not drawn once nobody active is off the list | drawing it unconditionally |
| the event form's box reserves rather than asks | the box calling the asking method |
| Ask the rest leaves an off-the-list member off | restoring the reservation inside the asking method |
| Save is disabled until a tick differs from what was drawn, and again once it is put back | the Stimulus controller enabling Save on any change |
| the notice counts places reserved and removed | the notice counting ticks |

## Verification

- Every new example seen red by its mutation, as "Seen red" says
- `git grep -inE 'invit' -- app/models/registration.rb app/models/event.rb app/policies/registration_policy.rb app/controllers/registrations_controller.rb app/controllers/events_controller.rb app/controllers/events app/controllers/registrations app/helpers/registrations_helper.rb app/helpers/events_helper.rb app/views/events app/views/layouts config/routes.rb db/seeds spec/models/registration_spec.rb spec/models/event_spec.rb spec/policies/registration_policy_spec.rb spec/helpers/registrations_helper_spec.rb spec/requests/events_spec.rb spec/support/styleguide_helper.rb spec/system/add_someone_spec.rb spec/system/event_detail_spec.rb spec/system/event_form_spec.rb spec/system/events_list_spec.rb` prints nothing
- `git grep -nE 'attendees|attendance card' -- app spec` prints nothing
- `bin/rspec spec/styleguide`, which `bin/ci` does not run
- `bin/ci`

Whether the new words read well is the owner's judgement, and no gate can see it: the grep proves the old word is gone, not that the new one is right. `reserved` is reachable from the screens for the first time, so views that only seeds drew it on get their first real traffic, and the system specs cover that only where they already create such a row.
