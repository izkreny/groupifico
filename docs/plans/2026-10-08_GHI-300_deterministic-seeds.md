> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Seed a deterministic data set covering every state

## One generator

`Faker::Config.random = Random.new(666)` gives Faker a generator of its own, and `Array#sample` in `db/seeds.rb` and in the `:from_the_past` and `:from_the_future` traits of `spec/factories/events.rb` keeps drawing from Ruby's unseeded global one. Faker falls back to the `Random` class when nothing is configured, so `srand(666)` at the top of the seeds seeds both from one generator, and the `Faker::Config.random` line goes. Checked in a throwaway script: two `srand` runs drew the same Faker name, `sample`, `shuffle` and `Faker::Date.between`.

## One clock

The whole run sits inside `travel_to(Time.current)`, required from `active_support/testing/time_helpers` as Fizzy does, so every `ago`, `from_now`, `created_at` and `updated_at` reads the same instant and the run cannot straddle midnight. The event traits anchor to the day, `Faker::Date.between(...) + 10.hours`, and with the day drawn from the seeded generator that is a fixed offset from the day of seeding, so events keep the traits' ten o'clock and the seeds pass no times of their own.

## The layout

`db/seeds.rb` keeps the empty-database guard, the generator, the clock and the helpers, and loads one file per data set with `require_relative`, the Fizzy shape:

- `db/seeds/sample_groups.rb` (new) carries today's Faker groups, with members as *Members and roles* below sets them. Registrations draw from all five `Registration` statuses. The address step runs per group instead of naming `groups.first` and `groups.second`, which is the whole reason `NUMBER_OF_GROUPS` could not change, so its TODO goes.
- `db/seeds/styleguide.rb` (new) carries the styleguide group: literal names throughout, taken from the in-memory samples on `app/views/styleguides/show.html.erb` where it has them, through the factories so they stay the authority on a valid record. One event per `Event` status plus an ongoing one, a confirmed upcoming event holding all five `Registration` statuses, and members as *Members and roles* below sets them.

`answer_then_settle` takes the statuses it writes instead of drawing them, so both files use it. A `reserved` or `invited` row needs no settling, since `Registration` checks only answers, but going through the one helper keeps the order it documents.

## Members and roles

A combination is a role set the member form can produce, held under one `Member` status. The role sets are the subsets of `Role::NAMES` in which no role `Role#implies?` another: none, `owner`, `administrator`, `events_administrator`, `members_administrator`, and the two module roles together. Six sets under three statuses make 18 combinations, derived from those two rather than listed, so a new role arrives seeded. A set the form greys, such as `owner` with `administrator`, stays out. A paused or inactive owner is valid beside an active one, since `Member` asks for an active owner on update only.

- **The sample groups** grow to 44 members each, `NUMBER_OF_MEMBERS_PER_GROUP` rising to match the events. 18 users belong to both and hold every combination once per group, rotated in the second, so one user holds a different combination in each. The other 26 in each group are its own, hold no role and draw `active`, `paused` or `inactive` with the odds rigged toward `active`.
- **A second active owner**, one of the first group's own members, is the one duplicate combination: with two the last-active-owner guard in `Member` and `Role` lets an owner step down, with one it refuses, and the second group keeps a single active owner so manual testing reaches both sides.
- **The styleguide group** has `NUMBER_OF_MEMBERS_PER_GROUP` members too, 44: the 18 combinations, a second active owner, and 25 plain members with no role. The member factory defaults to `active` and draws nothing, so the plain members draw their status with the sample groups' odds.

## The fixed key

`groups` has no slug or unique column, so the key is the id: `ActiveRecord::FixtureSet.identify(:styleguide)`, which is how Fizzy keys a seeded account and how Rails keys a fixture. The styleguide file runs last, because SQLite's `AUTOINCREMENT` continues from the highest id and the sample groups should stay at 1 and 2.

## Steps

- Write the determinism gate and the coverage gate in the session scratchpad, and watch both fail against the unchanged seeds on the test database.
- Swap `Faker::Config.random` for `srand` and wrap the run in `travel_to`.
- Move the sample groups into `db/seeds/sample_groups.rb` (new), with 44 members each, the shared users holding the rotated combinations, the drawn registration and member statuses, the second active owner and the address step per group.
- Write `db/seeds/styleguide.rb` (new) with the styleguide group under its fixed key.
- Rerun both gates and watch them pass, then reset the test database with `bin/rails db:test:prepare`.
- Run `bin/ci`.

## Verification

- The determinism gate exits 0: two `env RAILS_ENV=test bin/rails db:seed:replant` runs, each followed by a `bin/rails runner` digest of every name, status and relation and of every event time as its offset from the day of seeding, compare equal, having differed on the unchanged seeds
- The coverage gate exits 0: a `bin/rails runner` script finds every `Event` and `Registration` status and every combination in each sample group, held there by users who belong to both, and again inside the group under `ActiveRecord::FixtureSet.identify(:styleguide)`, with two active owners in the first sample group and one in the second, having failed on the unchanged seeds
- `bin/ci` is green

Both gates run against the test database and never the development one, which holds the owner's data, and stay in the scratchpad rather than the repository: whether anything committed reads the seeds is #346's question. No gate sees whether the styleguide group draws well on `/styleguide`, which is #301's work, or whether two replants a few seconds apart stand in for two on different days.

## Open questions

- Where does the key's label live once #301 reads it? Recommended: the styleguide seed file alone for now, since it is the one reader this issue has, and #301 moves it when it becomes the second.

## Settled

- Do the seeds carry roles? Yes: every role set the member form can produce, under every `Member` status, and #300's criteria now name them.
- How many members, and who is shared? 44 in each sample group, 18 of them users in both groups holding a different combination in each; 44 in the styleguide group too, its 25 plain members drawing their status rather than all being `active`.
- Are two members with identical roles worth seeding? Only for owners: the first sample group and the styleguide group each carry a second active owner, and the second sample group keeps one.
