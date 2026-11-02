> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: fix the flaky last-second link specs (#394)

## The fix

Each "signs in on the last second of the window" example, in `spec/models/sign_up_spec.rb` and `spec/models/sign_in_token_spec.rb`, wraps its body in `freeze_time do`, mints, calls `travel described_class::EXPIRES_IN` and redeems. `freeze_time` drops the fraction before the mint, so `expires_at` and the clock meet on the same whole second wherever the boundary falls. The nested `travel` takes no block because a nested block form raises. App code does not change.

## Why not the row's own `expires_at`

The issue's technical notes suggest traveling there, and it does remove the gap, but the clock then follows the row, so a mint that shortens the window passes. These two examples are the only ones catching that today: `(EXPIRES_IN - 1.minute).from_now` in `Redeemable.mint` turns exactly them red, while the `+ 1.second` examples only catch a longer window. Freezing keeps that coverage and adds some: the clock lands on the expiry instant itself, so an exclusive bound in `spend!` goes red too, which today's examples miss.

## Seen red

Both examples pass before the fix on almost every run, so each proof pins or mutates, in throwaway edits that are never committed:

- A throwaway spec pins the issue's moments, a mint at `12:00:00.999` and a read at `12:00:01.001`, against both models: the old line raises `InvalidToken` and the new form redeems.
- The same new form runs on the real clock with the mint held until just before a second boundary, and redeems.
- `(EXPIRES_IN - 1.minute).from_now` in `Redeemable.mint` turns both examples red.
- `expires_at: (now + 0.000001)..` in `Redeemable.spend!` turns both examples red.

## Steps

- Freeze the clock around the two examples, moving `travel_to` to a non-block `travel`
- Run the pinned moments and the mutations against the new form

## Verification

- `bin/rspec spec/models/sign_up_spec.rb spec/models/sign_in_token_spec.rb`
- The pinned moments and the real-clock run, as "Seen red" says: old line red, new form green, in both models
- Each mutation in "Seen red" turns both examples red
- `bin/ci`

No gate here runs the two examples across real second boundaries in CI, so the claim that the flake is gone rests on the pinned proof rather than on a long run of green builds.
