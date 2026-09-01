> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: quiet the default rspec output (#211)

## Approach

`.rspec` holds three lines: `--require spec_helper`, `--format documentation` and `--warnings`. Drop the last two and keep the first. Nothing else in the repository configures the formatter, so removing the flag is the whole change: `spec/spec_helper.rb` does carry the generator's `config.default_formatter = "doc"`, but it sits inside the `=begin` block that spans lines 49 to 93 and has never executed, which is #213's business rather than this branch's.

`.rspec` is the whole diff. The verbose run that replaces the flags is `bin/rspec --format documentation --warnings`, for when the question is which examples exist or which one hangs; neither flag goes back into `.rspec`, and neither belongs in a `.rspec-local` either, since that applies to every run in the checkout just the same. That belongs here and in the pull request body rather than in `.agents/testing.md`, per the decision recorded under `## Settled`.

## Steps

- Reduce `.rspec` to `--require spec_helper`
- Record the verbose invocation and the rule keeping the flags out of `.rspec`, in this plan and in the pull request body
- Measure a full run before and after, and record both figures in the pull request

## Verification

- `bin/ci` passes
- `bin/rspec` prints progress dots, the timing line and the counts, and no per-example names
- `bin/rspec spec/models/role_spec.rb` on a deliberately broken expectation prints the description, the message, the diff, the backtrace line and the rerun command

The gates cannot see whether the output is small enough to be worth the change, so the measurement is recorded as a number rather than a checkbox: 996 lines and 44.8 KB for 479 examples before, 19 lines and 4.7 KB after. They also cannot see that 14 of the 19 remaining lines are Rack's `:unprocessable_entity` deprecation warning, which #212 removes and which no flag here suppresses, because Rack emits it with a plain `warn` that `$VERBOSE` does not gate.

## Open questions

None.

## Settled

- **Where does the reason for the missing flags live?** In this plan and in the pull request body, never in `.agents/testing.md`. The reason a change was made is a historic fact about one change, and `.agents/testing.md` is read by every agent on every task, so a paragraph of history there is paid for on every read and drifts the moment the file it describes moves again. The plan and the body are fetchable by the change they belong to, and the body lands in the squash commit on `main`, so `git log` answers "why is `.rspec` one line" without anything standing rules have to carry. The rejected alternative was a `## Running the suite` section in `.agents/testing.md`, first as two paragraphs and then trimmed to two sentences; both were removed. Settled in a review thread on this pull request, 2026-09-01.
