> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Replace every Faker unique

## What is left to replace

`git grep` finds one call: `mobile_phone { Faker::PhoneNumber.unique.cell_phone_in_e164 }` in the `:with_all_attributes` trait of `spec/factories/user_profiles.rb`. Nothing in `db/seeds.rb`, `spec/support/` or any other factory calls `unique`, and the name fields lost theirs in #173. `mobile_phone` carries both a uniqueness validation in `app/models/user_profile.rb` and a unique index, so it takes the sequence branch of the rule; no field takes the drop-it branch today, which the `.agents/testing.md` sentence still states for the next one.

## The sequence

`sequence(:mobile_phone) { |n| format("+38591%07d", n) }` inside the trait: a Croatian mobile prefix, matching the application's one zone, and seven zero-padded digits. That is twelve digits after the `+`, inside E.164's fifteen, and it stays inside past ten million profiles. No spec reads the value, so nothing else changes.

## Watching it fail

The real pool is ten digits wide, so no run of this suite will exhaust it, and waiting for one proves nothing. The reproduction shrinks the pool instead of the run: a throwaway spec, kept in the session scratchpad and never committed, stubs `Faker::PhoneNumber.cell_phone_with_country_code`, the generator `cell_phone_in_e164` formats, to return two numbers, then creates three users through `:with_full_profile`. On the current factory the third raises `Faker::UniqueGenerator::RetryLimitExceeded`; on the sequence it passes, because the stub is no longer read. The mechanism is the one that broke #173, only with a pool small enough to see.

## Steps

- Write the throwaway reproduction spec in the scratchpad and run it with `bin/rspec` against the unchanged factory, watching it raise `Faker::UniqueGenerator::RetryLimitExceeded`.
- Run the `git grep` named under `## Verification` against the unchanged tree and watch it find `spec/factories/user_profiles.rb`.
- Replace the `mobile_phone` line in `spec/factories/user_profiles.rb` with the sequence, with a `WHY:` comment saying why Faker's `unique` is not used.
- Add the sentence the issue's fourth criterion asks for to the *Factories* section of `.agents/testing.md`: Faker's `unique` is a retry loop over a finite pool rather than a sequence, a constrained field takes a sequence, and an unconstrained one drops `unique`.
- Rerun the reproduction and the `git grep`, and watch both pass.
- Run `bin/ci`.

## Verification

- `bin/ci` is green
- `git grep -nE 'Faker::[A-Za-z:]+\.unique\.' -- '*.rb'` finds nothing, having found `spec/factories/user_profiles.rb` on the unchanged tree
- The scratchpad reproduction passes under `bin/rspec`, having raised `Faker::UniqueGenerator::RetryLimitExceeded` on the unchanged factory

The `git grep` exits 1 when it finds nothing, so that box is ticked on exit 1 and an exit 0 is the failure. No gate sees whether the reproduction's two-number pool is a fair stand-in for the real one; it shares the generator and the retry loop and differs only in the pool's width.
