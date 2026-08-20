> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: stop bin/ci leaving the test database seeded

Issue: #75

## Context

Reproduced on this branch before touching anything, which is what separates leftover state from a real regression. `storage/test.sqlite3` held 88 events, 43 users, 2 groups and 44 members, and a bare `bin/rspec` gave 97 examples and 4 failures: two in `Event.upcoming`, two in `Event.past`, each expecting an empty relation and finding seeded rows.

The cause is the last line of `config/ci.rb`. `bin/ci` runs `bin/rspec` and then seeds the test database, so the run is honestly green and everything after it is not.

Two things had to be read rather than recalled, because the fix is a one-line reorder and its correctness rests entirely on what these tasks actually touch.

**The rake tasks**, from `lib/active_record/railties/databases.rake` in `activerecord` 8.1.3.1:

- `db:seed:replant` is `task replant: [:load_config, :truncate_all, :seed]`, and `db:truncate_all` runs against the **current** environment. That is why the existing step carries `env RAILS_ENV=test` and why it cannot be dropped.
- `db:test:prepare` invokes `db:test:load_schema`, which is `db:test:purge` followed by a schema load. Both hardcode `env: "test"` and read `configs_for(env_name: "test")`, so the task needs **no** `RAILS_ENV` prefix and cannot reach the development database whatever the environment is.

**The runner**, from `lib/active_support/continuous_integration.rb` in `activesupport` 8.1.3.1: `step` is `report(title) { results << system(*command) }` and `success?` is `results.all?`. **No step aborts the run.** Every step executes regardless of what the previous ones returned, and the verdict is aggregated at the end. So a step placed after a failing one still runs, which is what makes any ordering here safe to reason about.

## Approach

Move the seed check ahead of the suite and reset the database between them:

    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
    step "Tests: Reset database", "bin/rails db:test:prepare"
    step "Tests: Rails", "bin/rspec"

**The reset goes before the suite, not after the seed check as the run's last step, and that is the whole design decision.** Both orders end with a clean database, so both satisfy the issue as written. Only this one is self-enforcing: delete the reset and `bin/rspec` runs on seeded rows inside `bin/ci` itself, so the run goes red on the spot. With the reset last, deleting it breaks nothing `bin/ci` can see, and the bug returns silently one command later, which is exactly how it arrived.

It buys a second thing on the way. `db:test:prepare` purges the file and reloads `db/schema.rb`, so the suite starts from schema on every run rather than from whatever last wrote to `storage/test.sqlite3`. `spec/rails_helper.rb` only calls `ActiveRecord::Migration.maintain_test_schema!`, which reloads on a *pending migration* and not on a database that merely has rows in it.

Rejected: giving the seed check its own database through a `DATABASE_URL` override. It works, and it is the more thorough reading of "the seed check should not touch the test database at all", but it adds a second database file, a second entry to keep out of git, and a config path that only `bin/ci` ever exercises. Three moving parts to buy what one reordered step buys.

Not touched: the two commented-out `bin/rails test` and `test:system` steps stay where they are, next to the `bin/rspec` line they are alternatives to.

## Steps

- Reorder the test block in `config/ci.rb`: `Tests: Seeds`, then a new `Tests: Reset database` running `bin/rails db:test:prepare`, then `Tests: Rails`
- Comment the reorder in place, one line on why the reset precedes the suite, since the ordering is the fix and a future edit that moves it would look harmless
- Run the verification sequence end to end, in order, with nothing between `bin/ci` and the `bin/rspec` that follows it

## Verification

Gates with an exit code, each the implementing agent's to run and tick:

- `bin/rspec` on the database as found, before the change: 97 examples, 4 failures. The reproduction, and it has already run
- `bin/ci`: green, every step
- `bin/rspec` immediately after `bin/ci`, nothing in between: 97 examples, 0 failures. This is the issue's first acceptance criterion, verbatim
- `sqlite3 storage/test.sqlite3 "select count(*) from events;"` immediately after `bin/ci`: `0`
- `bin/rubocop`, because `config/ci.rb` is Ruby and `Layout/LineLength` sits at rubocop's default of 120: `rubocop-rails-omakase` does not configure that cop, so the new comment has to fit
- `python3 /home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py` over this plan

The issue's third acceptance criterion, that deleting the seed step does not count as the fix, has no command. It is satisfied structurally: `Tests: Seeds` still runs `db:seed:replant` against the test database and still fails the run if `db/seeds.rb` raises.

What those gates cannot see:

- **Whether the seed check is worth anything.** It seeds a database that is then thrown away, so it proves `db/seeds.rb` executes without raising and nothing whatever about the rows it produced. That was already true before this change and the reorder does not make it worse, but it is the reason this step is cheap to get wrong twice.
- **The self-enforcing property, which is the reason for the ordering, rests on those four `Event` specs.** They fail on seeded rows today; a suite that stopped asserting on empty relations would stop catching a deleted reset step, and nothing would announce that.
- **GitHub Actions never exercises any of this.** `.gitignore` ignores `/storage/*`, so a runner builds an empty database from schema and has no state to leak. The failure is local-only, and the four CI jobs will pass on this branch whether the fix works or not.

## Open questions

- **Resolved.** The step is named `Tests: Reset database`. `Tests: Reset` alone was the proposal and reads as though the run itself is being reset; the extra word says which of the three things in play the step touches, and it still groups with the tests it feeds rather than with `Setup` three steps away.
