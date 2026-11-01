> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: reserve places and ask members to respond (#383)

## The words

Registering reserves a place, asking for a response is a separate later act, and "invite" stays for bringing someone into the group alone. Members may not know the word RSVP, so it leaves the screens and the code. The code takes these names:

| Now | Becomes | Why |
|---|---|---|
| status `invited` | `response_requested` | reads as a state like its neighbours, and `asked` would collide with the hand-written `Registration#asked?` |
| `Registration#invite` | `Registration#request_response` | |
| `Event#invite_all_active_members` | `Event#request_all_responses` | |
| `Event#anyone_left_to_invite?` | `Event#anyone_left_to_ask?` | |
| `Event#invite(members)` | `Event#reserve(members)` | replaced by the step that makes it write `reserved` |
| `Event#invite_active_members` | `Event#reserve_active_members` | the form's box, which now reserves |
| `resource :invitation`, twice | `resource :response_request`, twice | the noun for what the POST creates |
| `Events::InvitationsController`, `Registrations::InvitationsController` | `Events::ResponseRequestsController`, `Registrations::ResponseRequestsController` | |
| `invited_tally` | `list_tally` | it counts places, not questions |
| `ICONS[:invited]` | `ICONS[:response_requested]`, and `ICONS[:send_invite]` for `app/views/members/_form.html.erb` | that form's button is the group-joining sense, so it takes a key of its own on the same glyph |
| `app/views/events/_rsvp.html.erb` (delete) | `app/views/events/_response.html.erb` (new) | |
| `app/views/styleguides/app_partials/_rsvps.html.erb` (delete) | `app/views/styleguides/app_partials/_responses.html.erb` (new) | |

The rename needs no migration: `Registration`'s enum is declared as an array over an integer column, so `response_requested` keeps index 1 and every stored row keeps its meaning.

What stays: `app/views/members/new.html.erb`, `app/views/members/index.html.erb`, `app/views/members/_form.html.erb`'s "Send invite", `app/views/sessions/new.html.erb`, `app/controllers/sessions_controller.rb`, `app/views/groups/show.html.erb`'s "Invite the others", the styleguide's "your invitation was sent" alert and ADR 0004, all of which mean joining the group. `app/mailers/member_mailer.rb`'s comment says an invitation is a `Registration` status, so it is rewritten.

## The copy

| Where | Now | Becomes |
|---|---|---|
| member's reply row, once answered | Your answer: | the same question as before answering, "Are you coming?" or "Did you go?" |
| events list row label | your answer: yes | you said yes |
| roster heading | Who's invited | Who's on the list |
| both tallies | 3 of 5 invited | 3 of 5 on the list |
| paper plane, unasked | Invite Ana | Ask Ana if they're coming |
| paper plane, asked | Ana is invited, no reply yet | Ana was asked, no reply yet |
| status label | Invited, no reply yet | Asked, no reply yet |
| roster button | Invite the rest | Ask the rest |
| roster button, new | | Reserve a place for everyone |
| next-up button | Invite everyone | Ask everyone |
| notices | 2 members invited. / Nobody was left to invite. | 2 members asked. / Nobody was left to ask. |
| event form box | Invite all active members | Reserve a place for every active member |
| list screen and its roster button | Add someone | Edit the list |
| list screen, paused row | paused · can't be invited | paused · can't be added |
| list screen, submit | Invite 2 people | Update the list |
| list screen, notice | 2 members invited. | 2 places reserved, 1 removed. |
| list screen, moved on | Nobody was invited: nobody you ticked is still on the list. | Nothing changed: nobody you ticked is still on offer. |
| group home, empty | Add your first rehearsal and everyone gets asked whether they're coming. | Add your first rehearsal, then ask everyone whether they're coming. |
| refused answer, event over | Status cannot be answered once the event is over | This event is over, so it no longer takes replies. |
| refused answer, event ended | Status cannot be maybe once the event has ended | This event has ended, so it is a yes or a no. |

The frames still say "invited" in these places, and the issue overrides them. Yes, Maybe and No stay, because they answer the question directly. On Mobbin no app says "Your answer", and [Apple Invites](https://mobbin.com/screens/5a5a0fdb-b99a-4352-bd57-80680ca6862d) and [Google Calendar](https://mobbin.com/screens/cf44569a-9d69-403a-b292-f60e8b6e8299) never show the word RSVP.

## The list screen

`RegistrationsController#new` and `#create` become `Events::RostersController#edit` and `#update`, drawn by `app/views/events/rosters/edit.html.erb` (new) in place of `app/views/registrations/new.html.erb` (delete), under `resource :roster, only: %i[ edit update ], module: :events`, because one form both adds and removes and a `create` that deletes is not what the verb says. `RegistrationsController` keeps `update` alone, and `destroy` and its route go with the take-off. The Stimulus controller `app/javascript/controllers/invite_controller.js` (delete) becomes `app/javascript/controllers/list_controller.js` (new), which enables Update the list once a tick differs from what was drawn.

The screen's sections:

- **On the list**: every registered member, ticked, whatever their membership status. A paused or inactive member's registration can only be removed here once the roster loses its take-off, so they have to be drawn.
- **Not on the list**: active members unticked, then paused members with no checkbox, as today.

The form posts `member_ids[]`, the ticks, and a hidden `listed_ids[]`, the rows it drew ticked. Removal is `listed_ids` minus `member_ids`, never "everyone not ticked", so somebody registered while the form sat open is not removed unseen. Reservation stays `@group.members.active.without_registration_for(@event)` intersected with the ticks, which keeps the guard against an id from another group. Both go in one transaction in a new `Event#update_roster`, and the `RecordNotUnique` rescue stays.

Unticking somebody who answered removes the answer with the place, as the take-off does today.

**A manager may reserve and may not remove.** `RegistrationPolicy#create?` admits the event's manager and `#destroy?` does not, per `docs/AUTHORIZATION.md`. So:

- A manager's registered rows draw a ticked, disabled checkbox and a line beneath the name, "only an administrator can remove". They post no `listed_ids`, so nothing on their screen is certain to be refused. This is a deliberate difference from the paused row, which draws no checkbox, because a registered row is ticked for every reader.
- `Events::RostersController#update` asks `create?` always and `destroy?` whenever the removal set is not empty, of a registration with no member on it, and a refusal stops the whole request before any write. A forged removal is refused, never silently dropped.

The screen goes through the daisyUI Blueprint MCP server, with the `daisyui-blueprint-mcp` skill loaded first, in the `organic` and `organic-dark` themes.

## Reserving everyone

`Event#reserve_all_active_members` gives every active member with no registration a `reserved` one and touches nothing else, so an answer or a held place is never overruled. Paused members are skipped, and the roster's existing line names them as left out. These call it:

- The roster's "Reserve a place for everyone" button, through `resource :reservation, only: :create, module: :events`, drawn only while somebody active is off the list. Its notice is "3 places reserved."
- The event form's box, read after the save. The box stays on the edit form too, since `app/views/events/_form.html.erb` is shared, what it does there is equally true, and the issue does not ask for its removal.

A manager may press the button and cannot undo it, as with today's Invite the rest. An administrator cleans up, and `docs/AUTHORIZATION.md` says so.

## Asking

`Event#request_all_responses` moves held places only, and `Event#anyone_left_to_ask?` reads held places only. Being off the list is a choice now, so an asking button that also registered would undo every untick.

## Decided on the way

- **No `asked_at` column.** #382, the only reader, has no milestone, so the column would have no caller in this branch.
- **`Event#attendees` goes.** Nothing in `app/` reads it. Its shoulda line in `spec/models/event_spec.rb` goes with it, the assertion in `spec/requests/registrations_spec.rb` moves to `event.registrations`, and the comment naming it in the controller is reworded. `app/views/events/show.html.erb` stops saying "attendance card".

## Settled

- What should the status be called? `response_requested`, with `request_response` as the method that sets it. "RSVP" is used nowhere, screens or code.
- What replaces "Your answer:" once a member has replied? The question stays, "Are you coming?" or "Did you go?", and the lit button is the answer.
- What do we call a member who was asked and has not replied? "Asked, no reply yet".
- What does the button that asks people say? "Ask the rest", "Ask everyone", and "Ask Ana if they're coming" on the paper plane.
- What replaces "Who's invited" above the roster? "Who's on the list".
- Should Ask the rest also put active members who are off the list onto it? No, it asks held places only, and a new button reserves.
- What do the screen and its roster button say, now this is the only way to remove someone? "Edit the list".
- How do we offer reserving a place for everyone? "Reserve a place for everyone" on the roster, with no select-all on the list screen, so the issue's criterion moves to the roster.
- What does the list screen's submit say? "Update the list", with the notice reporting what happened.
- How does a manager's registered row look? A ticked, disabled checkbox with a caption, faded to 50% rather than daisyUI's 20%, so the tick reaches 3.11:1 in light and 4.41:1 in dark.
- What draws a checkbox's and an unpicked radio's outline? The text fields' own line, the theme's ink at 50%, at 3.11:1 in light and 4.40:1 in dark where daisyUI's default is 1.5:1 and 1.84:1. A picked radio keeps daisyUI's full ink, and keyboard focus keeps its primary border.

## Steps

- `refactor:` rename the status, methods, routes, controllers, partials, helpers and icon keys per "The words", specs included, with every string on screen unchanged and the existing suite passing.
- `feat:` change the copy per "The copy", with the strings the specs read.
- `feat:` make the list screen reserve the ticked members rather than asking them.
- `feat:` draw registered members ticked and remove the unticked, through `Events::RostersController`, with the manager's rows and the `destroy?` refusal.
- `feat:` take the take-off off the roster rows, deleting the specs that read it and adding no example for its absence.
- `feat:` add `Event#reserve_all_active_members`, the roster's button and the event form's box.
- `feat:` narrow asking to held places.
- `refactor:` remove `Event#attendees` and the "attendance card" wording.
- `docs:` bring `docs/AUTHORIZATION.md` and the README's entity description to the same words, including the manager's paragraph, keeping the capability table's column widths.
- `fix:` fade a manager's disabled tick to 50%.
- `fix:` draw checkbox and radio outlines with the text fields' line.
- Watch every new example go red per "Seen red".

## Seen red

| New example | What turns it red |
|---|---|
| ticking reserves, asks nobody | `Event#update_roster` writing `response_requested` |
| unticking removes the registration | dropping the removal from `Event#update_roster` |
| a member registered while the form sat open stays | removal computed as everyone not ticked |
| an id from another group is not reserved | unscoping the reservation lookup |
| a manager's posted removal is refused and nothing is written | dropping the `destroy?` check |
| a manager's registered row draws a disabled ticked box | drawing it enabled |
| a paused member's registration can be removed | listing active registrations only |
| reserving everyone skips paused members and leaves answers alone | dropping `.active`, and writing over existing rows |
| the roster's reserve button is absent once everyone active is listed | drawing it unconditionally |
| the event form's box reserves rather than asks | the box calling the asking method |
| Ask the rest leaves an off-the-list member off | restoring the reservation inside the asking method |
| Update the list is disabled until a tick differs from what was drawn, and again once it is put back | the Stimulus controller enabling it on any change |
| the notice counts places reserved and removed | the notice counting ticks |
| an answered member's row still asks the question | restoring the "Your answer:" branch |
| a manager can make out a registered row's tick, in light and in dark | daisyUI's 20% fade, before the rule |
| a live box's outline reads at 3:1, in light and in dark | daisyUI's 20% line, before the rule |
| an unpicked radio's outline reads at 3:1, in light and in dark | daisyUI's 20% line, before the rule |
| a picked radio's outline stays in full ink | the rule covering every radio |
| a focused unpicked radio keeps its primary border | the rule written with specificity, after the focus rules |
| the helper counts a border's own alpha | dropping the alpha from `ink_contrast` |
| the helper reads a solid border as solid | reading another property in `border_contrast` |

## Verification

- Every new example seen red by its mutation, as "Seen red" says
- `git grep -inE 'invit' -- app/models/registration.rb app/models/event.rb app/policies/registration_policy.rb app/controllers/registrations_controller.rb app/controllers/events_controller.rb app/controllers/events app/controllers/registrations app/helpers/registrations_helper.rb app/helpers/events_helper.rb app/views/events app/views/layouts config/routes.rb db/seeds spec/models/registration_spec.rb spec/models/event_spec.rb spec/policies/registration_policy_spec.rb spec/helpers/registrations_helper_spec.rb spec/requests/events_spec.rb spec/support/styleguide_helper.rb spec/system/add_someone_spec.rb spec/system/event_detail_spec.rb spec/system/event_form_spec.rb spec/system/events_list_spec.rb` prints nothing
- `git grep -inE 'rsvp' -- app config db spec README.md docs/AUTHORIZATION.md` prints nothing
- `git grep -inE 'attendees|attendance card|your answer' -- app spec` prints nothing
- `bin/rspec spec/styleguide`, which `bin/ci` does not run
- `bin/ci`

Whether the new words read well is the owner's judgement, and no gate can see it: the grep proves the old word is gone, not that the new one is right. `reserved` is reachable from the screens for the first time, so views that only seeds drew it on get their first real traffic, and the system specs cover that only where they already create such a row.
