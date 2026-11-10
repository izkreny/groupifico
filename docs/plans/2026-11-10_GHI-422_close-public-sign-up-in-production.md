> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: close public sign-up in production (#422)

## Approach

`resource :sign_up` and `resource :sign_up_confirmation` in `config/routes.rb` move inside an `if Rails.env.local?` block, the guard the styleguide and picks routes already use, with one `WHY:` line saying reopening is deleting it. The controllers, views, mailer, model and their specs stay as they are, so development and test route exactly as before. The proof follows the styleguide's own "its routes in production" examples in `spec/requests/styleguides_spec.rb`, which draw `config/routes.rb` into a fresh route set while `Rails.env` answers production and assert the path is not recognised; that differs from N3's reload-and-restore of the application's routes, because the fresh set never touches the routes the rest of the suite runs on. `docs/AUTHORIZATION.md` and `.agents/testing.md` still describe sign-up as a live route and stay unchanged, since the mechanism is kept and only production stops drawing it.

## Steps

- ::S1:: Add a "its routes in production" describe to `spec/requests/sign_ups_spec.rb` with one example each for `GET /sign_up/new` and `POST /sign_up`, and watch both fail against the unguarded `config/routes.rb`
- ::S2:: Add the same describe to `spec/requests/sign_up_confirmations_spec.rb` for `GET /sign_up_confirmation` and `POST /sign_up_confirmation`, and watch both fail against the unguarded `config/routes.rb`
- ::S3:: Wrap the two `resource` lines in `config/routes.rb` in `if Rails.env.local?` under a one-line `WHY:` comment, and commit it together with S1 and S2

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-10_GHI-422_close-public-sign-up-in-production.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-10_GHI-422_close-public-sign-up-in-production.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/sign_ups_spec.rb -e "its routes in production"` passes both examples, having been seen to fail both against `config/routes.rb` as it is on `main`
- ::V4:: `mise exec -- bin/rspec spec/requests/sign_up_confirmations_spec.rb -e "its routes in production"` passes both examples, having been seen to fail both against `config/routes.rb` as it is on `main`
- ::V5:: `mise exec -- bin/rubocop config/routes.rb spec/requests/sign_ups_spec.rb spec/requests/sign_up_confirmations_spec.rb` exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included, which is AC3's proof that the existing sign-up specs pass unchanged

The specs prove production draws no route, not that the live site serves a 404; that `https://chorifico.com/sign_up/new` answers 404 after the deploy, and that the deploy waits for the owner's own sign-ups per N4, are the owner's to judge.

## Open questions

None.

## Settled

None yet.
