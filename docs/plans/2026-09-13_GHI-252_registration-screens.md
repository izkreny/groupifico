> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the registration screens

## Which frame this is built from

Frame 9m, "Add someone", `GET /groups/:id/events/:id/registrations/new`, read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. Frame 9o is the refusal it names for everybody else, and that is `ApplicationController#deny_access` as it already behaves.

The frame is the only registration screen the design keeps. It draws a header with the event's name, its schedule and an "N of M invited" tally, a "Not on the list" section of checkbox rows, a dimmed untickable row for a paused member, and one full-width primary submit whose label counts what is ticked.

## What these screens are today

All six are the scaffold. `new` and `edit` render `registrations/_form`, a member picker over `members_available` and a status picker over every status; `index` is a list of `_registration` with Show, Edit and Destroy on each row; `show` is the partial and the same three controls. `RegistrationsController#create` takes one `registration[member_id]` and one `registration[status]`, and `new_registration_params` drops a `member_id` from another group so the model refuses the save.

So the redesign is four things: one screen replacing three, a form that posts a set rather than a record, a gate that refuses a member holding no role, and the removal of what the roster on the event detail supersedes.

## The gate on `new`, and the branch it makes dead

`new` builds `@event.registrations.new` and authorizes `create?`, whose `own?` answers true for a registration with no member on it. Every member of the group therefore reaches the screen today, which is what the third acceptance criterion refuses: the screen belongs to the invitation row of the events table in `docs/AUTHORIZATION.md`, the three roles and the event's manager.

That row already has a rule. `RegistrationPolicy#manage_answers?` is `membership.can_manage?(:events) || manages_event?`, which is the row exactly, and it is the right question rather than a convenient one: this screen writes `invited`, and `manage_answers?` is the rule that decides who may write a status that is not an answer about themselves. No table changes and no rule is added.

Gating `new` on it leaves `own?`'s nil-member branch reachable from nothing: `create` builds every registration with a member on it, so the branch and the comment justifying it by `new` both go in the same change. `create?` keeps `own?` for the member registering themselves, which the events table still grants and the policy spec still proves.

## Creating several registrations from one form

`create` takes `member_ids: []` and writes `invited` itself; the status never arrives from the form, because the one screen that posts here is the invitation screen. The posted ids are intersected with the eligible set - active members of this group with no registration on this event - rather than trusted, for the reason `foreign_member?` already states in its own comment: a registration written for somebody outside the group publishes their name through `Event#attendees` to people with no claim on it. Intersecting rather than rejecting also answers the race where a tick is already registered by the time the form is submitted.

Each built registration is authorized before the write, and the writes go in one transaction, so a set that is refused part way through leaves nothing behind. A submission with nothing ticked re-renders the screen with an alert rather than creating nothing silently.

`new_registration_params`, `foreign_member?` and `registration_statuses` all lose their last caller and go with it. `AppFormBuilder#absent_association` names `new_registration_params` in a comment and is corrected in the same commit.

## What is removed, and what waits for #251

`show` and `edit` are removed with their views, `registrations/_form` and their routes: nothing links to either except the scaffold `index` this screen replaces, and answering on a member's behalf is a roster row on the event detail, which is #251.

`index` stays for now. `app/views/events/_event.html.erb:15` still links to it, that file is #251's, and removing the link here would leave the registration list reachable from nowhere on `main`. Its Show and Edit links go, since their targets do; its Destroy stays as the only caller `destroy` has until the roster arrives.

`update` and `destroy` both redirect to `show` and `index` today. Both are re-pointed at `group_event_path`, the event whose roster is where the design puts those two actions, and `create` lands there too. `events/_rsvp` is the live caller of `update` and follows that redirect unchanged.

Removing `edit` leaves changing another member's answer with no screen until #251 lands. That is the issue's own trade, named here rather than discovered in review.

## Steps

- Rework `RegistrationsHelper`: `members_available` returns the group's members with no registration on the event, `inactive` excluded and active ordered before paused, and a sibling returns the "N of M invited" tally, N being the active members who are registered and M the active members. Drop `registration_statuses`. Extend `spec/helpers/registrations_helper_spec.rb` for the paused split, the inactive exclusion and the tally.
- Authorize `new` with `manage_answers?`, drop the nil-member branch from `RegistrationPolicy#own?` with the comment that justified it, and add the invitation-row examples for the new gate to `spec/policies/registration_policy_spec.rb`.
- Rewrite `RegistrationsController#create` to take `member_ids: []`, intersect them with the eligible set, authorize and save one `invited` registration each in a transaction, and redirect to the event; re-render the screen with an alert when nothing was ticked. Remove `new_registration_params` and `foreign_member?`, and correct the `AppFormBuilder#absent_association` comment that names the first.
- Remove `registrations/show.html.erb`, `edit.html.erb` and `_form.html.erb` with their actions, narrow the route to `%i[ index new create update destroy ]`, re-point `update` and `destroy` at `group_event_path`, and strip the Show and Edit links from `registrations/index.html.erb`.
- Rebuild `registrations/new.html.erb`: the "Add someone" title row through `shared/page_header`, the event's name, its schedule and the tally, a "Not on the list" list of checkbox rows carrying each member's name and status, a paused row dimmed with "can't be invited" and no checkbox, and a full-width primary submit.
- Add a Stimulus controller that counts the ticked boxes into the submit label and disables it at zero, and register it in `app/javascript/controllers/index.js`.
- Rework `spec/requests/registrations_spec.rb`: drop the `show` and `edit` describes, rewrite `new` for the refusal a member holding no role now gets, and rewrite `create` for the set, the ids it drops and the redirect.
- Add `spec/system/add_someone_spec.rb` for what only a browser adds: that the rows and the submit paint, that a paused row offers no checkbox, that ticking two and submitting lands on the event, and that the screen has no accessibility violations.
- Run `bin/ci` and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards. The checkbox row and the dimmed row are both the syntax expert's to settle rather than guessed here.

## Verification

- `bin/ci` is green
- `bin/rspec spec/system/add_someone_spec.rb` passes, and each new example is watched failing once before it is trusted

`bin/ci` is the only gate the browser suite has, since nothing reports it to GitHub. What no gate here can see: whether a dimmed paused row reads as "not available" rather than as a bug in both themes, and whether the tally says something a person filling an event actually wants to know.

## Open questions

- Whether `registrations#index` should go in this change, with the one link in `app/views/events/_event.html.erb` removed, rather than waiting for #251 to remove both. It waits, on the reasoning above.
- Whether the submit label counts live. It does: the server renders "Invite", and the Stimulus controller rewrites it to the frame's "Invite 2 people" and disables the button at zero, so the screen still submits with JavaScript off.

## Settled

None yet.
