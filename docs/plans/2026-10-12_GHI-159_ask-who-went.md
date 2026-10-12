> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: ask who went once an event has ended (#159)

## Approach

**One question decides what the answer row offers: which answers does this event take now.** It goes on `Event` as `Event#answers`, because the event owns both `ends_at` and `open_to_answers?`. It returns `Registration::ANSWERS` until the event ends and the same list without `maybe` afterwards. `Registration::ANSWERS`, `.answer?`, `#answered?`, `Event#answer_counts` and `Event#roster` stay as they are, since they describe the vocabulary rather than what is offered today.

**A second question decides who is asked: `Registration#asked?`.** Before the end it is `invited?`, so a `reserved` place still draws nothing on the upcoming list. After the end it is any status `Event#answers` no longer contains: `reserved`, `invited` and `maybe`. A `yes` or `no` given before the end is never asked again.

**The model refuses `maybe` once the event has ended**, through a new validation beside `event_must_be_open_to_answers` and guarded the same way: only an answer, only when the status changes, and only while the event is open, so a concluded event keeps the one message it has today. An existing `maybe` row saved for another reason is not touched.

**The three views read those two questions.** `events/_rsvp` draws for `asked?` or `answered?`, prompts with `EventsHelper#answer_prompt` when `asked?` and with "Your answer:" otherwise, offers `event.answers`, and keeps "no answer yet" for `invited` alone. `events/_rsvp` also takes the `open_to_answers?` guard that `events/_row` holds today, because `events/show` renders it with no guard, and a `reserved` member on a concluded event would otherwise be asked "Did you go?" over pills the model refuses. On a concluded or canceled event's screen the member's own answer row therefore disappears, and the roster's badge still shows what they said. `events/_row` asks on `asked?`. `events/_roster` offers `event.answers` and draws the badge whenever no pill is lit, so a pre-event `maybe` on an ended event still shows as a badge to whoever holds the pills.

**Existing setups that write `maybe` move before the end.** The event factory picks `starts_at` at random across a year, so `create(:registration, status: :maybe)` on a default event becomes a coin flip: `spec/models/event_spec.rb`'s `#roster` example and `spec/requests/events/invitations_spec.rb`'s answered registration get an upcoming event. `detailed_event` in `spec/requests/events_spec.rb` is fixed on 2026-09-02, so its three `reader_status: :maybe` callers run under `travel_to` the day before, as its `Are you coming?` example already does. `db/seeds.rb`'s `answer_then_settle` writes every status on past events, so it writes the answers of an ended event from the day before it started, and its comment says so.

## Steps

- `Event#answers` and `Registration#asked?`, with `spec/models/event_spec.rb` and `spec/models/registration_spec.rb` examples written from hand-derived literals and watched failing
- The `maybe` validation on `Registration`, its model examples watched failing, and in the same commit the spec setups above moved before the end
- `answer_then_settle` in `db/seeds.rb` writes an ended event's answers from the day before it started, with `travel_to` called without a block because the seeds already run inside one, and the clock restored afterwards
- `events/_rsvp`, `events/_row` and `events/_roster` read `Event#answers` and `Registration#asked?`, with `spec/requests/events_spec.rb` examples watched failing: on the past list a `reserved`, `invited` and `maybe` reader is asked "Did you go?" and a `yes` reader is not; the event screen of an ended event offers Yes and No and no Maybe, to the reader and on the roster; a concluded event's screen asks a `reserved` reader nothing; a manager sees the badge on a pre-event `maybe` row of an ended event
- Every new example that passes on the unchanged tree gets a named mutation and is watched failing under it, the mutation reverted before the next
- Run `bin/ci` in this worktree

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-12_GHI-159_ask-who-went.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' docs/plans/2026-10-12_GHI-159_ask-who-went.md` exits 0
- `bin/rspec spec/models/event_spec.rb spec/models/registration_spec.rb spec/requests/events_spec.rb spec/requests/events/invitations_spec.rb` passes, and each new or changed example was watched failing once
- `bin/ci` is green, which replants the seeds and so runs the changed `answer_then_settle`

No gate sees whether a two-pill row reads as a deliberate question rather than a row with a pill missing. That is a judgement on the screens.

## Open questions

None.

## Settled

None yet.
