> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0004. Passwordless email sign-in

## Status

Accepted, 2026-08-31. Supersedes nothing.

Records the decisions that #139, #207 and #208 build, so that those three cite this file rather than each carrying a copy of the reasoning.

## Context

Sign-in today is the stock Rails 8 authentication generator's output, untouched: `has_secure_password` on `User`, a `sessions` table, a signed permanent `session_id` cookie, and an `Authentication` controller concern resolving `Current.session`. #81 established that the README had described sign-in as a magic link for months while `db/schema.rb` had carried `password_digest` and a `sessions` table since March, so the passwordless flow this record settles has been claimed longer than it has existed.

#150 made it real and made it exclusive. Its plan file records the beta gate as "#139 passwordless email login, replacing the temporary password login", and its decisions section as "Passwordless email login (#139) is mandatory for beta; it joined the gates and the temporary password login left the definition". So this is a replacement, not an additional way in, and everything below follows from that.

The research behind it, each pass reading source rather than recalling it, per the standing rule in `CLAUDE.md` that `rails_rails` outranks everything on framework capability and that `basecamp_*` gets preference on application patterns:

- The framework itself, at `rails_rails`.
- The `steveclarke_real-world-rails` corpus, which yielded eight passwordless email implementations across seven apps once 2FA-on-password, OAuth, device-pairing tokens and unimplemented planning documents were filtered out.
- The Ruby Toolbox `rails_authentication` category, read for what a gem would buy.
- The source, tests and changelogs of `mikker/passwordless`, `devise-passwordless` and `rubymonolith/nopassword`, and then of `rodauth`, read for what each learned in production rather than for what each does.

This record exists because every decision below is invisible in the result. A reader of the finished code sees a confirmation page and cannot tell it is a security measure rather than a courtesy, sees a digest column and cannot tell that the most popular gem in this space stored raw tokens for its entire 0.x life, and sees fifteen minutes without knowing what else was on the table.

## Decision

### The framework was checked before anything was designed

`rails generate authentication` takes one option, `--api`, which chooses between an API-only and a full-views scaffold; both are password based, hardcoding bcrypt and a `password_digest` column. There is no magic-link support, no one-time-code support and no OTP primitive anywhere in Rails. Searching the framework for those terms turns up no authentication feature at all: the hits are a Permissions-Policy directive name, `otp` sitting in the filter-parameter list the app generator writes, a cache-key example in a changelog, and the `--otp` flag the release tooling passes to `gem push` and `npm publish`.

What Rails does ship and this uses: `rate_limit(to:, within:, by:, with:, store:, name:, scope:, **options)` in `actionpack/lib/action_controller/metal/rate_limiting.rb`, where `by:` defaults to `request.remote_ip` and returning something with a `cache_key` scopes it per account instead.

The check itself is the decision worth recording. Without it the obvious move is to reach for a gem, and the reason not to only becomes visible once it is established that the framework has neither the feature nor an opinion about it.

### A link, and not an emailed code

The first recommendation in this design was the emailed six-character code, on the strength of `basecamp_fizzy`, which sends a code and no link at all. It did not survive contact with the question of who actually uses this application.

Two of the arguments for the code were weaker than they looked. The mail-scanner problem is real, but it has a standard fix that costs one tap, so it argues for a confirmation page rather than against links. And "a link cannot be made single use" is true only of a self-contained signed token; once a row exists, a link is consumed exactly as a code is, so that argument was simply wrong.

What survives is a difference in where the session lands. **A link signs a person in on the device they tapped it on; a code signs them in on the device they typed it into.** For a phone-first audience reading email on that same phone, the link is one tap against reading and retyping six characters between two applications. The case it loses is a person at a laptop whose email is only on their phone, which is the minority here, and recoverable by asking again from somewhere they can read mail.

`basecamp_fizzy` chose the other way because it is a work tool used at a desk alongside a desktop application. House preference for Basecamp patterns is not a reason to inherit a decision made about a different audience.

**The code is deferred, not rejected.** It is the likely answer for SMS, which is #125: the reasons believed to favour it there are that phones autofill a code out of an incoming message and that carriers filter link-bearing texts harder than plain ones, both of which are recalled rather than read from a source and are for #125 to verify before it relies on either. Different channel, different answer, and the schema below is named so that adding a code later costs a delivery format rather than a redesign.

### A row, not a signed token

`generates_token_for` invalidates a token only when some value on the record changes, and nothing about a user changes when they sign in. A signed sign-in token would therefore stay replayable from an inbox for its entire window, with no way to spend it.

A row is what makes a link single use. It is also what keeps #125 possible at all, since a six-character code is far too short to carry a signature.

### Built here, and not adopted

Every passwordless-specific gem in the Ruby Toolbox `rails_authentication` category is built around the link: `mikker/passwordless`, `devise-passwordless` and `rubymonolith/nopassword` all mail one, and none of them treats a typed code as a flow of its own. `mikker/passwordless` comes closest, mailing its six-character token beside the link and rendering a field to type it into, `f.text_field :token` with `autocomplete: "one-time-code"`. The gem offering a code as a first-class flow is `rodauth-rails`, and it handles authentication through Roda middleware with its own session layer and table set, replacing `Current`, the `Authentication` concern, the signed cookie and the `sessions` table wholesale. That is an auth-stack transplant, not a feature adoption.

None of them claims Rails 8.1 support, and each is unbounded above rather than tested against it: `mikker/passwordless` declares `rails >= 5.1.4`, `rubymonolith/nopassword` declares `rails >= 7.0.1`, `rodauth-rails` declares `railties >= 5.2`, and `devise-passwordless` declares no Rails dependency at all, riding whatever Devise itself supports. That is compatibility by omission. Each gem is named with its owner throughout, because `nopassword` in particular is not a unique name: `creditario/nopassword` is a different project with a different gemspec and different constraints.

Reading their source turned the argument from a preference into a conclusion, because it showed what adoption would have meant inheriting. `mikker/passwordless` stored the raw token in the database for every 0.x release, and its 1.0 upgrade guide has to instruct every application using it to drop that column by hand, with `remove_column(:passwordless_sessions, :token, :string, null: false)`. Its `claim!` checks whether a row is claimed and then calls `touch`, with no transaction, no lock and no constraint, so two concurrent requests both pass. Its sign-in link guards only `HEAD` requests, under a comment that names the scanner problem correctly and then solves the wrong half of it. Its default delivery is `deliver_now`, inside the request. Its token generator is `CHARS.sample(6, random: SecureRandom).join`, and `Array#sample` draws without replacement, so the real keyspace is roughly 2^30 rather than 36^6.

`authentication-zero` is the useful one, as a blueprint rather than a dependency. It reaches the same shape Rails' own generator does, from the other direction, so its `--passwordless` output slots into the code already here: a small controller resolving `SignInToken.find_signed!`, one view, one mailer view, and a migration whose table carries a single `t.references :user` and nothing else. Its working lines are `@user.sessions.create!` and `cookies.signed.permanent[...]`, which is what `start_new_session_for` already does.

### The emailed link never authenticates

Opening the link renders a page. A `POST` behind that page's button starts the session.

Company mail filters open every link in a message before the recipient does. `mikker/passwordless` names this in a comment, "Some email clients will visit links in emails to check if they are safe", and then guards only `HEAD` requests, which misses every scanner that issues a full `GET`; no test in that suite covers even the `HEAD` case. `loomio` and `bike_index` both use an interstitial. `pupilfirst` and `dev.to` sign in directly on the `GET` and carry the risk, and `dev.to` compounds it by never spending its token.

Rodauth arrived at the same shape from the other direction, hardening this hop in 2.47.0 by no longer accepting the token as a parameter fallback on the second request.

### The token is a digest, travels in the query string, and is spent in one statement

**Stored as an HMAC digest, never raw.** A database dump then yields nothing usable. The section above has what `mikker/passwordless` had to tell its users to do instead.

**Rodauth runs the scheme the other way round, and that direction is rejected here rather than overlooked.** It stores the raw key and HMACs only the value that leaves in the email, so a database leak yields nothing without `hmac_secret`. For a single-purpose token, hashing before storage protects against a database-only leak just as well; rodauth inverts it because the same plumbing serves TOTP, where the raw shared secret has to stay computable and therefore cannot be pre-hashed. Nothing here shares that constraint.

**Carried in the query string, never in a path segment.** `ActionDispatch::Http::FilterParameters#filtered_path` returns `query_string.empty? ? path : "#{path}?#{filtered_query_string}"`, and `Rails::Rack::Logger` logs that value, so only the query string is ever filtered. A token in a path segment reaches the log in plaintext whatever `config.filter_parameters` holds. `mikker/passwordless` routes `/:resource/sign_in/:id/:token` and leaks on every redemption, and so does this repository today through `resources :passwords, param: :token`.

**Spent by one conditional `UPDATE`** matching the digest and the unconsumed state together, acting on the row count. Reading the row, comparing in Ruby and then updating by id is a time-of-check gap, and it is the one rodauth had to close in a release tagged `[SECURITY]`: "All features that used email tokens were subject to race conditions for concurrent requests using those tokens... addressed by expanding transaction scope and using FOR UPDATE on the query to retrieve the token to serialize the access." A single statement needs neither, because there is no separate read to race against.

**No account id in the link.** Rodauth's emailed value is the account id followed by an HMAC, so that redemption is an indexed single-row read rather than a search across outstanding tokens. An HMAC with a fixed key is deterministic, so a lookup by digest is already an indexed single-row read, and there is nothing to scan.

**Generated by `SecureRandom` at full width**, for the reason the `Array#sample` trap above demonstrates.

### Identical answers, including the clock

A response that matches in status and body is still distinguishable if one path waits on SMTP, so the mail is enqueued rather than delivered inside the request. `mikker/passwordless` defaults to `deliver_now` and has exactly this hole; `rubymonolith/nopassword` uses `deliver_later`.

The copy counts too, not only the redirect target. Rodauth's own default sends both cases to the same URL with the same status and then shows a different flash for an unknown address, which is a visible side channel shipped as a default.

`bike_index` is the deliberate outlier, showing a distinct error for an unknown address in exchange for a clearer message. That trade is available and is not taken here.

The wrinkle this application creates for itself is that #207 leaves no standalone sign-up page, the two ways in being to start a group or to be invited, so a person nobody invited who types their address into the sign-in form would otherwise be told to check an inbox nothing will ever arrive in. The message names the way out instead: ask the group's owner or an administrator for an invitation. It says the same thing to everyone, so it leaks nothing.

**It names one of those two ways and not both, and that is a choice about the audience rather than a route being withheld.** Somebody who reaches the sign-in form believes they already have an account, so the likely truths are that they were meant to be invited and were not, or that they typed a different address; neither is helped by being nudged into founding a group they never came to found. A person who does want to start one arrives by that route instead, which #207 builds and which this form is not the door to. The consequence to hold on to is that the same words reach everybody, the account holder included, so the invitation sentence has to read as ordinary rather than as a mistake to somebody whose link is already on its way.

### Both routes refuse a visitor who is already signed in

Rodauth's `check_already_logged_in` hook defaults to a no-op, and its own 2.47.0 notes call that out: "For backwards compatibility, Rodauth allows already authenticated sessions to access endpoints that are designed to be used by unauthentication sessions. This hightens the risk of account confusion attacks. It's strongly recommended that this configuration method be used to halt or redirect... (doing so prevented the webauthn_login vulnerability fixed in 2.46.0)."

That is a named vulnerability in shipped code, prevented in the applications that had set the hook. Both halves of this flow guard on it, not only redemption.

### A row per request, not a row per account

Rodauth's `account_email_auth_keys` makes the account id both the primary key and the foreign key, so an account has at most one outstanding link: a second request re-sends the same token rather than issuing another, redemption deletes the only row that could exist, and the table can never grow past the account count, which is why it needs no sweeping beyond a lazy delete on lookup.

It is a good design and it is rejected here for a specific reason. #207 issues a token before any account exists, since the user, the group and the owner membership are all created when the link is confirmed, so there is no account id to key the row by. A row per request also keeps a record of what was issued, which one row per account overwrites.

The cost is accepted rather than waved away: the table accumulates and needs a sweep. None of the gems surveyed has one, and `passwordless_sessions` in `mikker/passwordless` grows without bound behind a one-year default expiry.

### The invitation link is not a credential

#208 sends an invited person a link to the ordinary sign-in form with their address already filled in. That is a URL carrying a query parameter, not a token: no row, no digest, no expiry, nothing to spend, and nothing a mail filter can burn.

The alternative it replaces was a real invitation link with a longer window, first written as 48 hours, on the reasoning that unprompted mail may sit unread for a day. It is rejected because the longer window buys nothing. The invitation creates the `User` and the `Member` before the mail is ever opened, so an expired link locks nobody out: the person signs in through the form and gets a fresh fifteen-minute link. What a real invitation link would add is a second and looser credential to an application that otherwise has exactly one.

Matching the two windows at 24 hours instead was considered and rejected in the other direction. The argument for it was rodauth's own `email_auth_deadline_interval`, which defaults to a day. But that default arrives packaged with one outstanding link per account and a five-minute cooldown on resending, and a parameter lifted out of the design that constrains it is not the same decision as the design. A sign-in link is requested by somebody who is waiting for it, so a longer window buys no usability at all and only widens the time a live credential sits in a mailbox. Two windows differing because the recipient's situation differs is one rule applied twice, not two standards.

Two conditions make the pre-filled form safe, and both belong to #208. It must not submit itself, or every mail filter following the link would send the invited person a sign-in email nobody asked for, which is the confirmation page's reasoning arriving a second time. And the sign-in form's existing `rate_limit` is what covers it, since any address can already be typed there by anyone.

### Fifteen minutes

The corpus converges between ten and twenty: `bike_index` 10, `basecamp_fizzy` 15, `hcb` 15, `pupilfirst` 15, `dev.to` 20, with `loomio`'s configurable hour the outlier. Rodauth's own `email_auth_deadline_interval` defaults to a full day, so fifteen minutes is the conservative end of the range rather than the middle of it.

`discourse` is left out of that range deliberately, and the reason matters more than the number. Its 10 minutes is `EmailLoginCode::VALID_FOR`, which governs its emailed code; its link is an `EmailToken` bounded by `SiteSetting.email_token_valid_hours`, defaulting to 48. Reading the code's window as a link's would have narrowed the range using the credential this record did not choose, which is exactly the distinction the mechanism section above draws.

It is also the only window in the application, because the section above leaves one credential to have a window at all.

Under any magic-link scheme, access to the inbox is already access to the account. That is what makes a short window cheap rather than a long one safe: the argument cuts against extending, not for it. It also has a limit worth naming, since it holds only while an attacker has current access to the inbox. It does not cover a one-time capture, a forwarded thread, a screenshot, a mail backup or an old device, where a stale link is a credential outliving the access that produced it. Fifteen minutes is a hundredth of a day of that exposure, for a sign-in the person finishes in seconds.

## Consequences

**Passwords leave the application entirely.** `has_secure_password`, `users.password_digest`, `PasswordsController`, `PasswordsMailer` and its views, and the `resources :passwords` route all go, along with `User.authenticate_by` in `SessionsController`. Nothing is deployed yet, since #76 is open, so no live account holds a password and no transition path is needed. That window closes the day #76 lands.

**A token leak into the application log is fixed as a side effect.** `resources :passwords, param: :token` has been writing reset tokens into the log through `filtered_path`, and deleting the route ends it. It was found while reading `mikker/passwordless`, not while reading this repository.

**`start_new_session_for` gains `reset_session`, and the stored landing page goes.** `mikker/passwordless` shipped without the reset and added it in 0.11.0 as session-fixation protection. The severity here is low, because authentication rides its own signed cookie rather than the Rails session, so a fixed session id grants no login; what a planted session would reach is `session[:return_to_after_authenticating]`, pre-planted to steer where the person lands after signing in.

That key is therefore not stored at all. Reading it back across the reset would hand the steer straight back, and nothing in a browser session distinguishes the person who was refused at a page from an attacker who planted the same key in their browser, so there is no version of the feature that survives the reset. Returning somebody to where they were needs a destination the old session cannot reach, which means carrying it in the emailed link; that is a change nobody has scheduled, and until it happens sign-in lands at the root.

**Something has to sweep spent and expired rows**, which is the price of the row-per-request choice above.

**Adding the emailed code for #125 costs a delivery format, not a redesign**, because `sign_in_tokens` is named and shaped for a credential rather than for a link. `basecamp_fizzy` shows the alternative: its model is called `MagicLink` and it sends no link.

**If the HMAC key ever needs rotating**, rodauth's `compute_old_hmac` pattern is the one to copy: verify against the previous secret as a fallback, so no stored row has to be touched.

**A "sign out my other devices" screen has a precedent waiting.** Rodauth's `active_sessions` keeps one row per login holding an HMAC of a per-session id with `created_at` and `last_use`, checks it on every request, and lets logout drop one row or all of them. `SessionsController` already carries a comment anticipating such a screen, and its point is that revoking another device would be a different action, `DELETE /sessions/:id`, which needs a policy of its own: the skip names its actions precisely so that new action cannot inherit an exemption nobody chose for it. No issue exists for the screen.

**#139, #207 and #208 cite this record instead of repeating it.** Their technical notes carry what an implementer needs at hand, and the reasoning behind it lives here alone. That is the property to check when any of the four is edited, and it is the whole reason this record exists: a fact stated in two places has already begun to drift, whether or not anyone has noticed yet.
