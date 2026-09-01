> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add passwordless email login (#139)

How [#139](https://github.com/izkreny/groupifico/issues/139) gets built. The acceptance criteria live on the issue and are not repeated here; the reasoning behind every rule lives in [ADR 0004](../adr/2026-08-31_passwordless-email-sign-in_0004.md) and is not repeated either. This file answers *how*.

## The shape

Two controllers, because the flow has two halves and they refuse different things.

`SessionsController` keeps `resource :session` and gains nothing but a rewritten `create`: the sign-in form asks for an email, the `POST` enqueues a mail and answers the same way to everyone. From the person's side, submitting that form *is* asking for a session; it merely completes on a later request.

`SignInsController` is new and owns the emailed link. `GET /sign_in?token=…` renders a confirmation page and starts nothing; `POST /sign_in` spends the token and starts the session. They are separate actions on a separate resource because ADR 0004's *The emailed link never authenticates* is the whole point of the split, and a mail scanner following the link must reach an action that cannot sign anybody in.

The session is therefore started in `SignInsController#create` rather than `SessionsController#create`. That is the one place the route names and the mechanism diverge, and the alternative - renaming `resource :session` so the verbs line up - churns `new_session_path`, its specs and the `Authentication` concern's redirect for no gain a reader can use.

## Where the raw token lives, request by request

The value that must never be stored is the raw token, so trace it rather than trust it:

1. **Minted inside the mailer method**, not in the controller. `SignInMailer.link(user).deliver_later` serialises a `User` GlobalID into the job payload; minting in the controller and passing the token would serialise the raw token into `solid_queue_jobs.arguments`, which is exactly the datastore the digest column exists to keep it out of. The mailer carries a comment saying so, because a mailer with a write in it otherwise reads as a mistake.
2. **In the email**, as `sign_in_url(token: raw)` - a query parameter. `filter_parameters` already carries `:token`, and per ADR 0004 only the query string is filtered from the log.
3. **In the browser session**, put there by `SignInsController#show` reading `params[:token]`, and rendered nowhere on the confirmation page.
4. **Gone**, deleted from the browser session by `SignInsController#create` before it does anything else, so the failure path clears it too.

The digest is `OpenSSL::HMAC` over a key derived from `secret_key_base` through `Rails.application.key_generator`, so no new secret is introduced and ADR 0004's rotation note stays available.

## Steps

- Migration: create `sign_in_tokens` (`user_id`, `token_digest`, `expires_at`, `consumed_at`, timestamps) with a unique index on `token_digest` and a cascading foreign key to `users`, and drop `users.password_digest`.
- `SignInToken` model: `mint` returning the raw token, `digest`, `redeem!` raising a typed `SignInToken::InvalidToken`, and the expiry constant. `has_many :sign_in_tokens` on `User`, plus the callback that consumes outstanding tokens when an account's email changes.
- `SignInMailer#link` with html and text views, and its `sign_in_url(token:)` link.
- `Authentication` concern: `reset_session` inside `start_new_session_for`, and a `require_unauthenticated` filter for the two halves that refuse a signed-in visitor.
- `SessionsController#create` rewritten to look the address up, enqueue the mail when it resolves, and answer identically either way; `sessions/new` reduced to the email field.
- `SignInsController` with `show` and `create`, its route, its rate limit, and its `skip_verify_authorized` carrying the reasoning the deleted `PasswordsController` used to hold; `sign_ins/show` confirmation page whose button is the only thing that signs anybody in.
- Remove the password world: `PasswordsController`, `PasswordsMailer`, `app/views/passwords/`, `app/views/passwords_mailer/`, the `resources :passwords` route, `has_secure_password`, the `bcrypt` gem, `:password` from `UsersController#user_params` and from `app/views/users/_form.html.erb`, and `password` from the user factory.
- ADR 0004: add the clause to `### Identical answers, including the clock` saying why the message names the invitation alone though the record names two ways in.
- README: the sign-in bullet, the ERD's `password_digest` column, and the note listing which authentication tables the diagram leaves out.
- Specs, per the layers in [`.agents/testing.md`](../../.agents/testing.md): a model spec for `SignInToken`, a mailer spec for the link's shape, request specs for both halves, the email-change case on `User`, and the deletion of `spec/requests/passwords_spec.rb`.
- `bin/ci`.

## The two decisions #139 left open

**Redeeming one link invalidates every other outstanding link for that user.** Yes. The person is signed in on the device they wanted; a spare live link sitting in the same mailbox is exposure buying nothing. It costs one more `UPDATE` after the redeeming one, and it does not weaken the single-statement redemption, which still stands alone.

**No `secure_compare`, because there is no comparison to harden.** ADR 0004 spends the token with `UPDATE … WHERE token_digest = ? AND consumed_at IS NULL`. The match happens inside the database index; no Ruby ever compares two digests, so there is nothing for a constant-time compare to protect. Reintroducing a Ruby-side comparison in order to make it constant-time would be adding the vulnerability so as to fix it.

## What the specs have to prove that a happy path does not

- **Expiry at both boundaries**, with `freeze_time`: a token one second inside the window redeems, one second outside it does not.
- **A blank or malformed token raises `SignInToken::InvalidToken`**, never `NoMethodError` or `TypeError` out of the digest call.
- **A token minted for one user cannot authenticate another.**
- **The mechanism itself**, so a later refactor to `==` or `rand` fails rather than passes: that the generator is `SecureRandom` at no fewer than 128 bits, and that redemption is one conditional write rather than a read followed by a write.
- **Both halves refuse a signed-in visitor**, and the `GET` starts no session while the `POST` does.
- **The token leaves the browser session on the failure path too.**
- **Two uses of one link sign at most one person in.** Attempted first with two threads on separate connections, which is what the criterion actually says; SQLite serialises the writes, so one `update_all` returns 1 and the other 0. If that proves flaky under `busy_timeout` it drops to the sequential pair plus the single-write mechanism assertion above, and the PR says which one landed.

## Out of scope, deliberately

- **Sweeping spent and expired rows.** ADR 0004 names it as the price of the row-per-request choice and #139 makes no criterion of it. It needs its own issue.
- **The authentication ERD.** The README's note says a diagram comes "once passwordless login lands", and this branch fires that trigger without drawing it. The note is updated to name both undrawn tables instead, and the diagram is a follow-up.
- **`UsersController#new` and `#create`.** They stay until #207 retires them, per #139's technical notes, so the two branches do not collide on that file. Only the `:password` parameter and the form field go.

## Verification

- `bin/ci`

What that gate cannot see: whether the confirmation page reads as a deliberate step rather than a broken redirect, and whether the shared "check your inbox" copy reads as ordinary to somebody who *does* have an account rather than as a hedge. Both are judgements in a browser, not exit codes.
