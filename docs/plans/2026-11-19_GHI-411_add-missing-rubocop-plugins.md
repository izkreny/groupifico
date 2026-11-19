> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add the missing RuboCop plugins (#411)

## Approach

The four gems join `rubocop-rspec` in the Gemfile's development and test group with `require: false`, are installed with `mise exec -- bundle install`, which adds them and their own dependencies to `Gemfile.lock` and moves nothing already locked (N1), and are loaded under `plugins:` in `.rubocop.yml`. `rubocop-capybara` stays where it is: moving it is not this issue. `rubocop-rails-omakase` switches off whole departments it knows about, and none of these four is among them, so with `NewCops: enable` every cop of every new plugin is live, pending ones included, and `FactoryBot` cops reach `spec/**` as well as `spec/factories/`.

Each offense the new cops raise is fixed where the cop is right about the code, and the cop is reconfigured once in `.rubocop.yml` with a comment saying why where it is wrong for this repository, above all where it contradicts `.agents/testing.md`. No inline `rubocop:disable` is added (AC4). Two cases stop the chain with a question to the owner rather than a choice made here: a `ThreadSafety` offense whose fix would change behaviour, and a one-off case a generally right cop judges wrongly, which per `AGENTS.md` is a conversation rather than a config change.

## The `docs/plans/` decision (N3)

`docs/plans/` is excluded from `rubocop-md`, with the reason as a comment in `.rubocop.yml`. A plan is a dated record frozen at plan time, its Ruby blocks are often partial or illustrative, and rewriting a finished record to satisfy a linter changes the record without improving any code. Excluding the directory also keeps every future plan, which is committed alone before any code exists, from failing `lint` over an illustrative snippet. The cost is that no Ruby block in a plan is ever checked, which is accepted.

With `docs/plans/` out, no markdown file the repository maintains carries a `ruby`-tagged block today, so the plugin's live coverage starts empty and grows as docs gain Ruby. How `rubocop-md` treats untagged blocks is read from the installed gem's own default config, not assumed, and any untagged shell or prose block it parses as Ruby is handled by the same fix-or-reconfigure rule. AC3's proof is therefore the seen-red file in V3 rather than a block already in the tree.

## Hidden directories (N4)

RuboCop's file discovery is checked rather than assumed for the two hidden directories that matter. `.agents/*.md` is maintained markdown, so it is either linted or named in `.rubocop.yml` with the reason it is not (AC3); `.claude/*.md` are symlinks to those files and add nothing. `.claude/worktrees/` holds whole checkouts of other branches and must never be linted from the root. Inside a worktree that directory is empty and CI has none, so an inspection list that shows nothing under it proves nothing until a planted file there is seen to be skipped, which is V4.

## Steps

- ::S1:: Add `rubocop-factory_bot`, `rubocop-rake`, `rubocop-thread_safety` and `rubocop-md` to the `:development, :test` group of `Gemfile` beside `rubocop-rspec`, each with `require: false`, run `mise exec -- bundle install`, and check the `Gemfile.lock` diff by eye: only the new gems, their own dependencies and their `CHECKSUMS` lines (AC1)
- ::S2:: List the four under `plugins:` in `.rubocop.yml`, and exclude `docs/plans/` from markdown linting with the reason as a comment (AC1, AC3)
- ::S3:: Settle `.agents/*.md` and `.claude/worktrees/`: include the first or name it with the reason, and confirm the second stays out (AC3)
- ::S4:: Run `bin/rubocop` and clear every new offense, fixing the code where the cop is right and reconfiguring the cop in `.rubocop.yml` with a comment where it is wrong for this repository, with no inline `rubocop:disable` (AC2, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-19_GHI-411_add-missing-rubocop-plugins.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '.claude/worktrees/' docs/plans/2026-11-19_GHI-411_add-missing-rubocop-plugins.md` exits 0
- ::V3:: `mise exec -- bin/rubocop` on four scratch files, deleted after, reports one offense from each plugin: a factory with a static attribute under `spec/factories/` (`FactoryBot`), a task with no `desc` under `lib/tasks/` (`Rake/Desc`), a class-level `attr_accessor` under `app/models/` (`ThreadSafety`), and a markdown file outside `docs/plans/` whose `ruby` block breaks a cop omakase enables, picked from `--show-cops` (AC2, AC3); the same four files are seen passing clean on `main`'s config first, which is the seen-red
- ::V4:: `mise exec -- bin/rubocop -L` lists no path under `.claude/worktrees/` or `docs/plans/` while scratch Ruby and markdown files that break a cop are planted in both; seen red by listing the planted `docs/plans/` file before the exclusion lands, and the inspected-file count before and after the config change is compared so an exclusion that swallows the whole tree cannot pass (AC3)
- ::V5:: `git diff main -- '*.rb' '*.rake' '*.md' ':!docs/plans'` adds no line containing `rubocop:disable`, and `mise exec -- bin/rubocop` exits 0 on the tree (AC2, AC4)
- ::V6:: `mise exec -- bin/ci` passes, browser suite included (AC5)

What these gates cannot see: whether a cop reconfigured in S4 was wrong for this repository or merely inconvenient, which is a judgement each `.rubocop.yml` comment states and the review reads.

## Open questions

None.

## Settled

None yet.
