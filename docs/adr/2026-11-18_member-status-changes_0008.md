> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0008. Member status changes

## Status

Proposed, 2026-11-18.

Records what #329 decided about how a member's status changes, so #126 and the issues that hang off it cite this file rather than each carrying the reasoning. One choice is still open: whether the transitions are written in plain Rails or with the `state_machines` gem, which waits on questions put to that gem's maintainers. Everything else below is decided, and this record moves to Accepted when that choice is made.

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

### One verb method per transition, and no callbacks

Every change of the current status goes through a named method on `Member`, such as approving, pausing or deactivating, whichever path asks for it: the member form, an edit or delete of the current row, or an approval. In one transaction the method checks that the move is allowed, writes the change and the copy, and runs the cleanup below, and it queues the email with `ActiveRecord.after_all_transactions_commit`, as `Registration#request_response` already does, so a rolled-back save sends nothing. Imports and edits to past rows write rows directly and fire nothing.

No model callback reacts to the status column. A sweep of every status writer found that a callback would also fire for the CSV import, the seeds and the test factories, all of which must stay silent, and the house style keeps business logic out of callbacks.

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

Both get the same shape, history included: a list of allowed transitions, a verb method per transition, and a row per change. Their timing differs from a member's, since a registration can go from `yes` to `maybe` to `no` in one afternoon, so whether their changes are dated or timestamped, and whether the one-change-a-day rule holds, is decided per model.

### Still open: plain Rails or `state_machines`

Plain Rails expresses the pattern with an enum, a constant of allowed transitions, and the verb methods, using only what Rails 8.1 ships. The `state_machines` family covers the transitions, the guards and the after-commit email, and nothing in it covers the dated, editable history, which is hand-built either way. The findings are under *Alternatives considered*. The maintainers have been asked about the gaps, and the answer decides this one choice.

## Alternatives considered

**A callback on `saved_change_to_status?`**, the most common shape among production Rails applications without a state-machine gem. It fires for every writer, the silent ones included, and hides the side effects of a transition from whoever reads the method that made it.

**The `state_machines` gem with its Active Record integration**, `state_machines` 0.305.0 and `state_machines-activerecord` 0.304.0, read in their repositories and tried against this app's enum shape:

- It requires Ruby 4.0 and Active Record 8.1, which this app runs, and its CI runs on SQLite.
- `before_transition` runs inside the save's transaction and `after_transition` with `after_commit: true` waits for the outermost commit, which is what the cleanup and the email need. Guards and refusal reasons come with it.
- On an existing integer enum, states declared without values worked with `{ pending: 3, active: 0, paused: 1, inactive: 2 }`: every transition stored the enum's integer, a refused event returned `false` with an error, and the enum's predicates, scopes and `validate: true` kept working. Declaring the integers explicitly beside the enum failed on create with "Status is invalid".
- Beside an enum it generates prefixed methods, 16 per model for four statuses (`status_active?`, `status_active!`, `status_active`, `not_status_active`), and prints a method-conflict warning for each enum predicate when the class loads. In 0.304.0 the prefix and the scopes are fixed rather than configurable.
- `direct_assignment: :allow`, the default, leaves plain `update` and `update_columns` outside the machine, so imports stay silent.
- Its releases 0.300 to 0.305 shipped between 15 and 17 November 2026, two of them changing behaviour, among them the `around_transition` semantics and the `direct_assignment` default.
- `state_machines-audit_trail` 4.0.0 is an append-only log stamped with the save time, with no way to backdate, edit or delete a row, so it can sit beside a history but cannot be one.

**Other state-machine gems.** In the public real-world-rails corpus, about 39 of 239 applications use one: aasm in 14, the `state_machines` family in about 10, and Statesman, workflow and transitions in a few each. None of the 37signals applications (Fizzy, Campfire, Writebook) uses one, and neither does Hitobito, the association-management application closest to this domain. Statesman keeps a transitions table, and Sharetribe still writes the current state back onto the parent row, which is the copy this record keeps. None of the gem-using applications read backdates a transition. The comments in the applications that use a gem record its costs: callbacks skipped by bulk writes and copied by hand (GitLab), a callback returning `false` silently stopping the chain (Gumroad), and `skip_callbacks` flags (Catarse).

**Stored end dates.** Hitobito's roles, the World Cube Association's user roles and Whitehall's role appointments all store an end, because their periods can have gaps. These have none, so the end is a derived fact here.

**State as a single record**, Fizzy's `Closure` beside a card. One row per state answers "is it closed" but holds no history.

**A cached status recomputed from dated periods**, as Bike Index does. Its periods end on a date with no save, so the cache goes stale until something saves the row. Refusing future dates is what keeps the copy here exact.

## Consequences

**#126 builds this**, and #322 and #330 wait for it, so the release-candidate work in this set waits on the open choice. The history screen and the history import are their own issues, and returning a member to their events is a draft.

**Every write of a status goes through the verb methods or through the history edit**, never through `update(status:)` from a controller. #448 ships its approval as a plain write and moves onto the approval method when #126 lands.

**Statistics read status from the history** (#115), so a member's registrations are never edited to make a report come out right.

**The vocabulary** is status change for the stored row, period for the derived span, and updater for whoever last wrote it. #353 carries the terms into the glossary.

**`Event` and `Registration` each get a draft** for their history, naming the timing question.
