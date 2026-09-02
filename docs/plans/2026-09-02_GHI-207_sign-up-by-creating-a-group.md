> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Sign up by creating a group

Implementation plan for [#207](https://github.com/izkreny/groupifico/issues/207). The acceptance criteria live on the issue; this file answers how.

## Context

There is no sign-up page. `UsersController#new` and `#create` are what a signed-in user reaches through `resource :user`, and nothing signed out reaches an account at all: `_navigation.html.erb` offers "Log in" and nothing else. #139 landed the passwordless flow this builds on, so `sign_in_tokens`, `SignInsController` and the confirmation page all exist and work for one purpose.

The sign-in mechanism and every decision behind it are [ADR 0004](../adr/2026-08-31_passwordless-email-sign-in_0004.md). This plan cites it and does not restate it.

## What the reference corpus does and does not settle

The issue's technical notes cite `basecamp_fizzy`'s `MagicLink#purpose`, and reading it changes two things about this plan rather than confirming both halves of the citation.

**The `purpose` enum is real and worth copying.** `app/models/magic_link.rb` carries `enum :purpose, %w[ sign_in sign_up ], prefix: :for, default: :sign_in`, a `purpose` integer column that is `null: false`, and `db/migrate/20251129110120_add_purpose_to_magic_links.rb` adding it against existing rows by backfilling `0` before the `null: false`. The `for_` prefix is what makes `token.for_sign_up?` read as a fact about the token, and this plan takes it.

**Fizzy does not scope its lookup by purpose, and this application must.** `MagicLink.consume(code)` scopes by `active` and `code` alone, and `Sessions::MagicLinksController` reads `magic_link.for_sign_up?` only *after* consuming, to pick a redirect. That is safe there and unsafe here for one reason: Fizzy's `belongs_to :identity` is not optional, so every row it consumes resolves to a real credential whatever its purpose, and the branch decides only where the person lands. A row here may carry no `user_id` at all, so an unscoped lookup would hand a sign-up row to `SignInsController#create`, where `redeem!` ends in `find_by!(token_digest: wanted).user.tap { … }` and raises `NoMethodError` on `nil`. The issue's own note that "every lookup is scoped to the purpose it was issued for" is therefore the load-bearing half of the citation, and the half Fizzy does not demonstrate.

**Deferred account creation has no precedent in the corpus, and that is the finding.** Fizzy's `Signup#create_identity` runs `Identity.find_or_create_by!(email_address:)` *before* it sends the link, so the credential exists eagerly and only the tenant is deferred, driven by session state after authentication rather than by anything on the token row. Nothing in `basecamp_*`, `rails_rails` or the `steveclarke_real-world-rails` corpus stores pending account data on a token row and materialises the account on confirmation. Edge Rails does not offer it either: `ActiveRecord::TokenFor`'s `payload_for(model)` is `[model.id, block.as_json]`, so a `generates_token_for` token always names a persisted row, and `resolve_token` re-derives that row from `payload[0]` before comparing. There is no framework facility for a signed token belonging to no record yet.

So the shape #207 asks for is being built rather than borrowed, and every invariant it needs has to be proven here. That is the argument for the model-level validations below: nothing upstream is enforcing them on this application's behalf.

## Decisions

**One table, not a second one.** `sign_in_tokens` gains the sign-up purpose rather than a `sign_ups` table beside it. ADR 0004's window is "the only window in the application, because the section above leaves one credential to have a window at all", and a second table is a second credential: a second digest scheme, a second expiry, a second sweep, a second thing to get the conditional `UPDATE` wrong in. The cost is that `user_id` becomes nullable and every invariant it used to carry for free now has to be written down.

**The row carries the address and the group name; `purpose` is what makes both readable.** A sign-up row has no user to belong to, so it holds the email address itself, and the group name has to survive from the form to the click on a possibly different device. The browser session cannot hold either: the link exists to be openable elsewhere, which is the case the browser session cannot serve. `Session` cannot hold them either, since that row exists only once sign-in has succeeded.

**Confirmation is one transaction that contains the spend.** The conditional `UPDATE` goes inside `transaction do` alongside the three creates, so a validation failure rolls the spend back and leaves the link live for a retry rather than burning it. Today's `redeem!` runs no transaction and needs none, because spending is all it does. Two concurrent confirmations still resolve the way ADR 0004 describes: the `UPDATE`'s row count is the only arbiter and there is no separate read to race against.

**Confirming one sign-up does not consume the address's other outstanding sign-up rows.** `redeem!` consumes a user's other outstanding tokens because a signed-in person has no use for a second live sign-in link. A sign-up row is not interchangeable that way: two rows for one address carry two different group names and two different intents, so confirming the first must not silently discard the second. The user's *sign-in* tokens are consumed on confirmation exactly as `redeem!` does it, because by then there is a session.

**The owner membership moves onto `Group`, because it acquires a second caller.** `GroupsController#create` builds it inline today. #138's plan put it there deliberately, arguing that a model would have to reach for `Current.user` from inside itself; a method taking an explicit `user:` argument reaches for nothing, so that argument does not forbid the extraction and the second caller is what asks for it. The extracted method uses `Role::OWNER`, which `Group#owned_by_anyone_but?` already uses and the controller currently spells as a literal.

**Two singular resources, mirroring the sign-in pair, rather than a branch inside `SignInsController`.** Fizzy redeems both purposes in one controller, and its branch is one line choosing a redirect. Here the sign-up branch is a transaction creating three records, so a `case purpose` inside `SignInsController#create` would put two credentials' redemption in the security-critical method ADR 0004 spends four sections on. The form and the emailed link stay split the way `resource :session` and `resource :sign_in` are split, for the same reason: asking for a link and redeeming one are different actions with different guards.

**The shared parts of redemption become a concern rather than a second copy.** `hold_token_from_query_string` is where ADR 0004's "the emailed link never authenticates" is actually implemented, along with the reason the page names the account: a link nobody sent you is otherwise indistinguishable from your own. Reimplementing that beside it is how one copy drifts. Two callers is early for an extraction, and this one is taken anyway because what would be duplicated is the security measure.

**The sign-up form is rate limited, and for a reason `sessions#create` does not have.** That action mails only an address with an account; this one mails any address given to it, so it is a mail-bombing vector as well as a brute-force one. The limit is keyed on the submitted address alongside the IP.

**The mint happens in the mailer.** `SignInMailer#link` mints there so `deliver_later` serialises a global id rather than writing a raw token into `solid_queue_jobs.arguments`. The sign-up mail carries the address and the group name, neither of which is secret, so the same shape holds and the fifteen minutes start when the mail is built.

**`GroupsController#new` and `#create` are kept.** See `## Open questions`.

## Out of scope

- **The sweep ADR 0004 says is owed.** The row-per-request choice accepted that the table accumulates. No issue exists for it and no criterion here asks; adding one nullable purpose does not change the arithmetic.
- **The authentication ERD.** `README.md:80` records that neither `sessions` nor `sign_in_tokens` is drawn in the main diagram and that they get one of their own. Changing the columns of an undrawn table changes no diagram.
- **`SessionsController::LINK_SENT`.** ADR 0004's "It names one of those two ways and not both" is a deliberate choice about who reaches that form, and this branch is not the occasion to reopen it.

## Steps

- Migrate `sign_in_tokens`: add `purpose` (integer, `null: false`, default `0`), `email` (string, limit 250, nullable) and `group_name` (string, limit 250, nullable), and make `user_id` nullable. Confirm the SQLite adapter's `change_column_null` rebuild keeps the foreign key rather than assuming it does, and re-run `bin/rails db:migrate` so `annotaterb` rewrites the schema block on every affected model
- Teach `SignInToken` the two purposes: the `for_`-prefixed enum, `belongs_to :user, optional: true`, `validates :user, presence: true, if: :for_sign_in?`, presence of `email` and `group_name` `if: :for_sign_up?`, and the same `normalizes :email` `User` carries, so confirmation compares one spelling
- Split minting and lookup by purpose: `mint_for_sign_in(user)` and `mint_for_sign_up(email:, group_name:)`, and scope `pending` and `redeem!` to `for_sign_in` so a sign-up row cannot resolve there
- Add `SignInToken.redeem_sign_up!`: one transaction holding the conditional `UPDATE`, `User.find_or_create_by!(email:)`, the group and its owner membership, so a failure anywhere leaves the link live and no records behind
- Extract the owner membership onto `Group`, taking the user explicitly, and call it from both `GroupsController#create` and the confirmation path
- Add `SignUpsController` (`new`, `create`) behind `resource :sign_up, only: %i[ new create ]`, with `allow_unauthenticated_access`, `refuse_authenticated`, `skip_verify_authorized`, the rate limit keyed on the address and the IP, and a response identical whether or not the address already has an account
- Add `SignUpConfirmationsController` (`show`, `create`) behind `resource :sign_up_confirmation, only: %i[ show create ]`, with the same guards, and extract the token-from-query-string handling it shares with `SignInsController` into a controller concern
- Add `SignUpMailer#link` and its two views; the mail names the group and the fifteen minutes, and the mailer mints
- Add the two views: the form asking for a group name and an address, and a confirmation page naming both the address and the group before its button, for the reason `hold_token_from_query_string`'s comment gives about a planted link
- Link the form from `_navigation.html.erb` beside "Log in", so a signed-out visitor can reach it
- Retire `UsersController#new` and `#create`: narrow `resource :user` to `%i[ show edit update destroy ]`, shrink the `skip_verify_authorized` list, rewrite the comment whose second paragraph argues about exactly those two actions, and delete `app/views/users/new.html.erb`. Check first whether Action Policy's `skip_verify_authorized` is a `skip_after_action`, which `raise_on_missing_callback_actions` would make a boot failure if the named actions are gone. `app/views/users/_form.html.erb` stays, because `edit` renders it
- Rewrite the "Starting a group is not a membership question and has no row" paragraph in `docs/AUTHORIZATION.md` to state both doors, and align `GroupPolicy`'s header comment with it
- Specs, per `.agents/testing.md`: `spec/models/sign_in_token_spec.rb` for the purpose validations, the purpose-scoped lookups and the transaction's all-or-nothing; `spec/requests/sign_ups_spec.rb` and `spec/requests/sign_up_confirmations_spec.rb` covering every action in both signed-in and signed-out contexts; the retired examples out of `spec/requests/user_spec.rb`; and the `sign_in_tokens` factory gaining a `:for_sign_up` trait rather than callers building the shape inline

## Verification

- `bin/ci`

Each of these is watched failing before it is trusted: the purpose-scoped lookup, against a sign-up token fed to `sign_in#create`, which must be refused rather than raising `NoMethodError`; the transaction, against a version that spends outside it, so an invalid group leaves a burnt link; and the presence validations, against a row built with the wrong purpose's fields.

What that gate cannot see: whether the confirmation page reads as the deliberate last step of signing up rather than as an extra hoop, whether naming both the address and the group there reads as a safety check rather than as noise, and whether a "Start a group" link sitting beside "Log in" reads as an invitation rather than as a second login. All three are judgements in a browser.

## Open questions

- **Do `GroupsController#new` and `#create` survive this branch?** The issue's technical notes read as though they do not - "The actor for `new?` and `create?` is now anonymous" - but no acceptance criterion retires them, and criterion 4 has the new owner landing on a group page, which is the signed-in surface. This plan keeps them and rewrites `docs/AUTHORIZATION.md` to state two doors: a signed-in user through `GroupPolicy#create?`, and an anonymous visitor through sign-up confirmation, which is not an authorization question at all because there is no actor until the act creates one. That second door is also why `SignUpConfirmationsController` carries `skip_verify_authorized`: `authorize :user, through: -> { Current.user }` raises `AuthorizationContextMissing` with no user, so `authorize!` is not callable there. The argument for keeping them is that ADR 0004's `refuse_authenticated` guards the sign-up form, so under the other reading a signed-in user would have no route to a second group at all. Say if the other reading is meant, and how a signed-in user then starts one.

## Settled

None yet.
