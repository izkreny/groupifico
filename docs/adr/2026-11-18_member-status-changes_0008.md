> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0008. Member status changes

## Status

Accepted, 2026-11-21.

Records what #329 decided about how a member's status changes, so #126 and the issues that hang off it cite this file rather than each carrying the reasoning. It was proposed on 2026-11-18 with one choice open, plain Rails or the `state_machines` gem family, and the owner chose the gem family on 2026-11-21, on the evidence below and before its maintainers had answered the questions put to them.

## Context

A member's status is one value on the membership, `pending`, `active`, `paused` or `inactive`, overwritten on every change, so nothing records when it changed, who changed it, or what it was before. Several pieces of work hang off a change: #322 emails the member, #330 cleans up their registrations, #448 approves a request to join, and #92 and #126 asked for dates and history. Each would otherwise add its own hook.

The history is a hard requirement rather than a nice-to-have. A group's reports to its umbrella organisation (#115) count each member's presence over a season, and an absence while paused is excused rather than missing, so the app has to know a member's status on any past date. Some groups bring six years of history from spreadsheets, so dates are backdated and corrected by hand.

`Event` and `Registration` carry statuses too, and #101 asks for rules about which `Event` statuses may follow which.

## Decision

### History is a row per status change

`Member::StatusChange` holds `status`, `starts_on` and `updater`. A row says that from `starts_on` on, the member's status is `status`. A **period** is derived, never stored: it runs from one change's `starts_on` to the day before the next change's, and the current period has no end. A membership never has a gap, because a member who leaves gets an `inactive` change rather than no row, so the next start fully determines every end and storing ends would only add a second fact that could disagree with the first.

`members.status` stays, as a copy of the latest change's status, written in the same save as every change and every edit that moves the latest row. `Member.current`, the policies and every screen that reads the status keep querying the column, rather than joining to the latest row per member.

### The rules of a history

- `starts_on` is a date and never after today, so a status never switches on by itself on a later day and the copy cannot go stale.
- At most one change per member starts on any day. A second change on the same day is refused, and the day's row is edited instead.
- A new change never starts before the latest change's `starts_on`, so it always becomes the latest row and the copy follows it. A row added further back is a history edit, which leaves the current status alone.
- An edit keeps a row's date strictly between its neighbours' dates, so the history never reorders.
- When a delete or a status edit leaves two neighbouring rows with the same status, they merge and the earlier row is kept.
- The member's only row cannot be deleted.
- The group always keeps an active owner. `Member`'s existing validation enforces it, because every change that moves the current status writes the copy through `Member`'s own save.

The owner, the administrator and the members administrator may add, edit and delete rows, the same columns `docs/AUTHORIZATION.md` lets change a member's status. An owner edits their own history like anyone else's.

### The updater is whoever last wrote the row

`updater` is a `Member`, set to the acting member by every write and overwritten by every edit, and the history screen shows it as "by Ana". It is not called `creator`, because `Event#creator` is set once and never changes, and one word must not mean two things.

`updater_id` is nullable, with a foreign key that nullifies on delete, until soft delete (#87) means a member is never deleted. The one-time backfill also leaves it null. A required `updater` would repeat #143, where a required `creator` whose member was deleted makes the event impossible to save.

### Every member starts with a change

Every way a member comes into being writes the first change in the same save. The "Add member" form and the member edit form carry a start date that defaults to today. A join request and a new group's owner start today, the import brings its own dates, and the one-time backfill gives every existing member one change dated the day their membership was created.

### One event per transition, and no model callbacks

Every change of the current status fires a named event on `Member`'s state machine, such as approve, pause or deactivate, whichever path asks for it: the member form, an edit or delete of the current row, or an approval. In one transaction the machine checks that the move is allowed and saves the status, a `before_transition` runs the cleanup below, and the audit trail writes the status change row, while an `after_transition` with `after_commit: true` queues the email, so a rolled-back save sends nothing. An edit or delete of the current row writes its own row change and fires the event only for its callbacks, and the audit trail's `if:` option, evaluated with the event's arguments, skips the insert on that path. Imports and edits to past rows write rows directly and fire nothing.

No model callback reacts to the status column. The machine's transition callbacks run only for an event, so the CSV import, the seeds and the test factories, which write the column without one, stay silent. A sweep of every status writer found that a callback on the column would fire for all of them, and the house style keeps business logic out of callbacks.

### What each transition does

- **Approving a request to join**, `pending` to `active` (#448), sends the welcome email and nothing else.
- **A move among `active`, `paused` and `inactive`** sends #322's email for the new status.
- **Leaving `active`** for `paused` or `inactive` removes registrations from `starts_on` on, split by where each event stands:
  - an event that has not ended loses every registration of the member, answered or not;
  - an event that has ended but is still open to answers (`unconfirmed` or `confirmed`) loses only unanswered ones, because an answer there may be the record that the member was at the rehearsal;
  - a `concluded` or `canceled` event is never touched.
- **Returning to `active`** adds no registration. Which events a returning member rejoins is a question of its own, because rosters are chosen per event.

### The past is read, never rewritten

A status change never edits a concluded event. A member's status on any date is read from the history, so statistics decide whether a `no` counts as missing by asking whether the member was active that day, and correcting a pause's dates corrects every report without touching a registration.

### The pattern carries over to `Event` and `Registration`

Both get the same shape, history included: a state machine with its allowed transitions, an event per transition, and a row per change. Their timing differs from a member's, since a registration can go from `yes` to `maybe` to `no` in one afternoon, so whether their changes are dated or timestamped, and whether the one-change-a-day rule holds, is decided per model.

### The transitions use the `state_machines` family

`state_machines-activerecord` drives the transitions, and `state_machines-audit_trail` writes each one as a `Member::StatusChange` row, through `class:` and through `context:` methods that read the new status from `transition.to` and `starts_on` and `updater` from the event's arguments, and its `if:` option skips the row when a history edit of the current row has already written it. Editing, deleting and importing that history stay hand-built, as they would be either way.

The versions are pinned exactly: `state_machines-activerecord` 0.304.0 with `state_machines` 0.305.0 and `state_machines-activemodel` 0.300.0, and `state_machines-audit_trail` 4.0.0. They move only as a deliberate step of an update round, because 0.300 to 0.305 shipped within three days with behaviour changes.

These costs are accepted for now, each raised upstream: the enum integration adds prefixed methods and prints a conflict warning for each enum predicate when the class loads; the status change model carries no-op `event=`, `from=` and `to=` writers and an `alias_attribute` for its status, because the audit trail always assigns those three; and the first row's date reaches the audit trail through an attribute set on the member, because the initial entry carries no event arguments. States are declared by name beside the enum, never with `value:`, which breaks creation.

The evidence, from reading the repositories and running the gems against this app's enum shape:

- The gems require Ruby 4.0 and Active Record 8.1, which this app runs, and their CI runs on SQLite.
- `before_transition` runs inside the save's transaction and `after_transition` with `after_commit: true` waits for the outermost commit, which is what the cleanup and the email need. Guards and refusal reasons come with it.
- On an existing integer enum, states declared without values worked with `{ pending: 3, active: 0, paused: 1, inactive: 2 }`: every transition stored the enum's integer, a refused event returned `false` with an error, and the enum's predicates, scopes and `validate: true` kept working. Declaring the integers explicitly beside the enum failed on create with "Status is invalid".
- Beside an enum it generates prefixed methods, 16 per model for four statuses (`status_active?`, `status_active!`, `status_active`, `not_status_active`), and prints a method-conflict warning for each enum predicate when the class loads. In 0.304.0 the prefix and the scopes are fixed rather than configurable.
- `direct_assignment: :allow`, the default, leaves plain `update` and `update_columns` outside the machine, so imports stay silent.
- The core and Active Record releases 0.300 to 0.305 shipped between 15 and 17 November 2026, two of them changing behaviour, among them the `around_transition` semantics and the `direct_assignment` default.
- `state_machines-audit_trail` 4.0.0 writes a row per transition inside the save's transaction, into a model the app chooses with `class:`, and a `context:` method that takes the transition can fill columns such as a start date and an updater from the event's arguments. It never touches a row afterwards, so backdating, editing, deleting and importing stay the app's own writes, and it always assigns `event`, `from` and `to`, which a model without those columns would need setters for.
- Rechecked on 2026-11-21: no release and no code change in any of the four gems since those versions.

## Alternatives considered

**A callback on `saved_change_to_status?`**, the most common shape among production Rails applications without a state-machine gem. It fires for every writer, the silent ones included, and hides the side effects of a transition from whoever reads the method that made it.

**Plain Rails**: an enum, a constant of allowed transitions and a verb method per transition, using only what Rails 8.1 ships. It carries none of the costs above, at roughly twice the transition code per model, and it was the recommendation until the audit trail turned out to write the history rows already.

**Other state-machine gems.** In the public real-world-rails corpus, about 39 of 239 applications use one: aasm in 14, the `state_machines` family in about 10, and Statesman, workflow and transitions in a few each. None of the 37signals applications (Fizzy, Campfire, Writebook) uses one, and neither does Hitobito, the association-management application closest to this domain. Statesman keeps a transitions table, and Sharetribe still writes the current state back onto the parent row, which is the copy this record keeps. None of the gem-using applications read backdates a transition. The comments in the applications that use a gem record its costs: callbacks skipped by bulk writes and copied by hand (GitLab), a callback returning `false` silently stopping the chain (Gumroad), and `skip_callbacks` flags (Catarse).

**Stored end dates.** Hitobito's roles, the World Cube Association's user roles and Whitehall's role appointments all store an end, because their periods can have gaps. These have none, so the end is a derived fact here.

**State as a single record**, Fizzy's `Closure` beside a card. One row per state answers "is it closed" but holds no history.

**A cached status recomputed from dated periods**, as Bike Index does. Its periods end on a date with no save, so the cache goes stale until something saves the row. Refusing future dates is what keeps the copy here exact.

## Consequences

**#126 builds this**, and #322 and #330 wait for it. It adds the four gems at their pinned versions and records them in `.agents/dependencies.md` as moved only on purpose. The history screen and the history import are their own issues, and returning a member to their events is a draft.

**Every write of a status goes through the machine's events or through the history edit**, never through `update(status:)` from a controller. #448 ships its approval as a plain write and moves onto the approve event when #126 lands.

**Statistics read status from the history** (#115), so a member's registrations are never edited to make a report come out right.

**The vocabulary** is status change for the stored row, period for the derived span, and updater for whoever last wrote it. #353 carries the terms into the glossary.

**`Event` and `Registration` each get a draft** for their history, naming the timing question.
