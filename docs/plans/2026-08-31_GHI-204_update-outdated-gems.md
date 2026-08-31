> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update outdated gems (#204)

## Approach

`bundle update --all` against the ten gems `bundle outdated` named. Eight resolved to their latest release; `diff-lcs` and `marcel` did not move, both held below 2.0 by upstream constraints rather than anything in this repository's own `Gemfile`: `rspec-expectations`/`rspec-mocks` pin `diff-lcs (>= 1.2.0, < 2.0)`, and Rails' `activestorage` pins `marcel (~> 1.0)`. Neither is a defect to fix here.

## Steps

- Run `bundle update --all`
- Confirm which gems moved and why the remaining two did not

## Verification

- `bin/ci` passes

Only `Gemfile.lock` changed; no application code was touched, so `bin/ci`'s test suite is the whole gate.

## Open questions

None.

## Settled

None yet.
