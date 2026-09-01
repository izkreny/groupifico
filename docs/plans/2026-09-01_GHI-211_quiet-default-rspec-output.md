> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: quiet the default rspec output (#211)

## Approach

`.rspec` holds three lines: `--require spec_helper`, `--format documentation` and `--warnings`. Drop the last two and keep the first. Nothing else in the repository configures the formatter, so removing the flag is the whole change: `spec/spec_helper.rb` does carry the generator's `config.default_formatter = "doc"`, but it sits inside the `=begin` block that spans lines 49 to 93 and has never executed, which is #213's business rather than this branch's.

Then add a `## Running the suite` section to `.agents/testing.md`, after `## Framework choices`, recording `bin/rspec --format documentation --warnings` as the verbose invocation and when it is worth reaching for. That file points at [`.agents/gh-solo.md`](../../.agents/gh-solo.md) for the local gate, so this section names the verbose run and does not restate that `bin/ci` is the gate.

## Steps

- Reduce `.rspec` to `--require spec_helper`
- Add `## Running the suite` to `.agents/testing.md` with the verbose invocation and when to use it
- Measure a full run before and after, and record both figures in the pull request

## Verification

- `bin/ci` passes
- `bin/rspec` prints progress dots, the timing line and the counts, and no per-example names
- `bin/rspec spec/models/role_spec.rb` on a deliberately broken expectation prints the description, the message, the diff, the backtrace line and the rerun command

The gates cannot see whether the output is small enough to be worth the change, so the measurement is recorded as a number rather than a checkbox: 996 lines and 44.8 KB for 479 examples before, 19 lines and 4.7 KB after. They also cannot see that 14 of the 19 remaining lines are Rack's `:unprocessable_entity` deprecation warning, which #212 removes and which no flag here suppresses, because Rack emits it with a plain `warn` that `$VERBOSE` does not gate.

## Open questions

None.

## Settled

None yet.
