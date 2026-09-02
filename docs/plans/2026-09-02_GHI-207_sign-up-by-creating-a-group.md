> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Sign up by creating a group

Implementation plan for [#207](https://github.com/izkreny/groupifico/issues/207). The acceptance criteria live on the issue; this file answers how.

## Context

There is no sign-up page. `UsersController#new` and `#create` are what a signed-in user reaches through `resource :user`, and nothing signed out reaches an account at all: `_navigation.html.erb` offers "Log in" and nothing else. #139 landed the passwordless flow this builds on, so `sign_in_tokens`, `SignInsController` and the confirmation page all exist and work.

The sign-in mechanism and every decision behind it are [ADR 0004](../adr/2026-08-31_passwordless-email-sign-in_0004.md). This plan cites it and does not restate it.

## What the reference corpus does and does not settle

The issue's technical notes cite `basecamp_fizzy`'s `MagicLink#purpose`, and reading it produced the finding that reshaped this plan rather than confirming it.

**Fizzy creates the credential eagerly, so it never faces the problem #207 poses.** `Signup#create_identity` runs `Identity.find_or_create_by!(email_address:)` *before* it sends the link, and `Signups::CompletionsController` creates the account only once the person is already authenticated. So the deferral is driven by session state after authentication rather than by anything stored on the token row, and `MagicLink`'s `belongs_to :identity` is never optional. That is also why `MagicLink.consume(code)` can scope by code and expiry alone and read `for_sign_up?` only afterwards to pick a redirect: every row it consumes resolves to a real credential whatever its purpose.

**Deferred account creation has no precedent in the corpus, and none in the framework.** Nothing in `basecamp_*`, `rails_rails` or the `steveclarke_real-world-rails` corpus stores pending account data on a token row and materialises the account on confirmation. Edge Rails does not offer it either: `ActiveRecord::TokenFor`'s `payload_for(model)` is `[model.id, block.as_json]`, so a `generates_token_for` token always names a persisted row, and `resolve_token` re-derives that row from `payload[0]` before comparing. There is no framework facility for a signed token belonging to no record yet.

So the shape #207 asks for is being built rather than borrowed, and every invariant it needs has to be written down here. That is the argument for the model-level validations below: nothing upstream is enforcing them on this application's behalf.

## Decisions

**A table of its own, not a purpose on `sign_in_tokens`.** `sign_ups` is purely additive: nothing on `sign_in_tokens` changes, `user_id` stays `null: false`, every existing finder keeps its meaning, and `SignInsController` needs no branch. The alternative put a `purpose` enum and three nullable columns on the credential table, and the trap that alternative carried is concrete: `redeem!` ends in `find_by!(token_digest: wanted).user.tap { … }`, so a user-less row reaching it raises `NoMethodError` rather than being refused, and every finder would have to be re-scoped to keep that from happening. The deeper reason is what the two rows are. A `sign_in_tokens` row is a credential and nothing else. A `sign_ups` row is a request to start a group that happens to be redeemable, so it carries domain facts (an address, a group name) that a credential table has no business holding.

**One credential mechanism, in two tables.** ADR 0004's fifteen minutes is "the only window in the application", so both rows share it, along with the HMAC digest scheme and the single-statement spend, through a model concern rather than a second copy. What is not shared is the key label: `key_generator.generate_key` is called with a label derived from the model name, so the two tables have independent keyspaces. Nothing exploits a shared one, since every lookup is already confined to its own table, but independent is the right default and costs a string.

**The extraction is a behaviour-preserving step of its own.** Moving the digest, the mint and the conditional `UPDATE` off `SignInToken` and into the concern changes no behaviour and lands separately from anything that does, with the existing `spec/models/sign_in_token_spec.rb` green across it. Fowler's rule, and the reason it is worth the discipline here is that the code being moved is the part ADR 0004 spends four sections on.

**Confirmation is one transaction that contains the spend.** The conditional `UPDATE` goes inside `transaction do` alongside the three creates, so a validation failure rolls the spend back and leaves the link live for a retry rather than burning it. Today's `SignInToken.redeem!` runs no transaction and needs none, because spending is all it does. Two concurrent confirmations still resolve the way ADR 0004 describes: the `UPDATE`'s row count is the only arbiter and there is no separate read to race against.

**Confirming one sign-up does not consume the address's other outstanding rows.** `redeem!` consumes a user's other outstanding sign-in tokens because a signed-in person has no use for a second live link. A `sign_ups` row is not interchangeable that way: two rows for one address carry two different group names and two different intents, so confirming the first must not silently discard the second. The user's *sign-in* tokens are consumed on confirmation exactly as `redeem!` does it, because by then there is a session.

**The owner membership moves onto `Group`, because it acquires a second caller.** `GroupsController#create` builds it inline today. #138's plan put it there deliberately, arguing that a model would have to reach for `Current.user` from inside itself; a method taking an explicit `user:` argument reaches for nothing, so that argument does not forbid the extraction and the second caller is what asks for it. The extracted method uses `Role::OWNER`, which `Group#owned_by_anyone_but?` already uses and the controller currently spells as a literal.

**Two singular resources, mirroring the sign-in pair.** The form and the emailed link stay split the way `resource :session` and `resource :sign_in` are split, because asking for a link and redeeming one are different actions with different guards.

**The shared parts of redemption become a controller concern rather than a second copy.** `hold_token_from_query_string` is where ADR 0004's "the emailed link never authenticates" is actually implemented, along with the reason the page names the account: a link nobody sent you is otherwise indistinguishable from your own. Reimplementing that beside it is how one copy drifts. Two callers is early for an extraction, and this one is taken anyway because what would be duplicated is the security measure.

**The sign-up form is rate limited, and for a reason `sessions#create` does not have.** That action mails only an address with an account; this one mails any address given to it, so it is a mail-bombing vector as well as a brute-force one. The limit is keyed on the submitted address alongside the IP.

**The mint happens in the mailer.** `SignInMailer#link` mints there so `deliver_later` serialises a global id rather than writing a raw token into `solid_queue_jobs.arguments`. The sign-up mail carries the address and the group name, neither of which is secret, so the same shape holds and the fifteen minutes start when the mail is built.

**`GroupsController#new` and `#create` are kept, and the two paths divide by whether a user exists.** Sign-up defers creation because there is no user yet and nobody has proven they control the address; `groups#create` defers nothing, because the session is that proof. So they are not two doors to one outcome: one creates an account around a first group, the other creates a group for an account that already exists. See `## Settled`.

## Out of scope

- **The sweep ADR 0004 says is owed.** The row-per-request choice accepted that rows accumulate, and `sign_ups` accumulates the same way for the same reason. No issue exists for it and no criterion here asks.
- **Approval of a new group by an app-scoped administrator.** Settled below as a reason this table is shaped well for it, not as work this branch does. No issue exists, and every name in `Role::NAMES` is group-scoped, so it needs an authorization axis this application does not have.
- **The authentication ERD.** `README.md:80` records that neither `sessions` nor `sign_in_tokens` is drawn in the main diagram and that they get one of their own; `sign_ups` joins them as undrawn. Adding a table nothing draws changes no diagram.
- **`SessionsController::LINK_SENT`.** ADR 0004's "It names one of those two ways and not both" is a deliberate choice about who reaches that form, and this branch is not the occasion to reopen it.

## Steps

- Extract the shared credential mechanism off `SignInToken` into a model concern: the HMAC digest with a key label derived from the model name, `EXPIRES_IN`, the mint, the `outstanding` scope, `InvalidToken`, and the conditional `UPDATE` as a `spend!` returning the row. Behaviour preserving, its own commit, with `spec/models/sign_in_token_spec.rb` green across it
- Migrate `create_table :sign_ups`: `email` (string, limit 250, `null: false`), `group_name` (string, limit 250, `null: false`), `token_digest` (string, `null: false`, unique index), `expires_at` (`null: false`), `consumed_at` (nullable), timestamps. No foreign key, because the point of the row is that no user exists yet
- Add `SignUp` on the concern, with `normalizes :email` matching `User`'s so confirmation compares one spelling, and presence and length validations on both domain columns
- Add `SignUp.redeem!`: one transaction holding `spend!`, `User.find_or_create_by!(email:)`, the group and its owner membership, so a failure anywhere leaves the link live and no records behind, and consume the user's outstanding sign-in tokens once there is a session
- Extract the owner membership onto `Group`, taking the user explicitly, and call it from both `GroupsController#create` and `SignUp.redeem!`
- Add `SignUpsController` (`new`, `create`) behind `resource :sign_up, only: %i[ new create ]`, with `allow_unauthenticated_access`, `refuse_authenticated`, `skip_verify_authorized`, the rate limit keyed on the address and the IP, and a response identical whether or not the address already has an account
- Add `SignUpConfirmationsController` (`show`, `create`) behind `resource :sign_up_confirmation, only: %i[ show create ]`, with the same guards, and extract the token-from-query-string handling it shares with `SignInsController` into a controller concern
- Add `SignUpMailer#link` and its two views; the mail names the group and the fifteen minutes, and the mailer mints
- Add the two views: the form asking for a group name and an address, and a confirmation page naming both the address and the group before its button, for the reason `hold_token_from_query_string`'s comment gives about a planted link
- Link the form from `_navigation.html.erb` beside "Log in", so a signed-out visitor can reach it
- Retire `UsersController#new` and `#create`: narrow `resource :user` to `%i[ show edit update destroy ]`, shrink the `skip_verify_authorized` list, rewrite the comment whose second paragraph argues about exactly those two actions, and delete `app/views/users/new.html.erb`. Check first whether Action Policy's `skip_verify_authorized` is a `skip_after_action`, which `raise_on_missing_callback_actions` would make a boot failure if the named actions are gone. `app/views/users/_form.html.erb` stays, because `edit` renders it
- Rewrite the "Starting a group is not a membership question and has no row" paragraph in `docs/AUTHORIZATION.md`: starting a group as a signed-in user stays the authorization question `GroupPolicy#create?` answers, and signing up is named as an account-creation route whose side effect is a first group rather than as a second group-creation route, so it raises no authorization question at all. Align `GroupPolicy`'s header comment with it
- Specs, per `.agents/testing.md`: `spec/models/sign_up_spec.rb` for the validations, the expiry and the transaction's all-or-nothing; `spec/requests/sign_ups_spec.rb` and `spec/requests/sign_up_confirmations_spec.rb` covering every action in both signed-in and signed-out contexts; the retired examples out of `spec/requests/user_spec.rb`; and a `sign_ups` factory

## Verification

- `bin/ci`

Each new check is watched failing before it is trusted: the transaction, against a version that spends outside it, so an invalid group leaves a burnt link; the two key labels, against a version deriving one label for both models, so a `sign_ups` digest and a `sign_in_tokens` digest stop being independent; and the expiry, against a row whose `expires_at` is in the past.

What that gate cannot see: whether the confirmation page reads as the deliberate last step of signing up rather than as an extra hoop, whether naming both the address and the group there reads as a safety check rather than as noise, and whether a "Start a group" link sitting beside "Log in" reads as an invitation rather than as a second login. All three are judgements in a browser.

## Open questions

None.

## Settled

- **Do `GroupsController#new` and `#create` survive this branch?** Yes. Settled by the owner in the terminal, 2026-09-02. The issue's technical notes read as though they do not - "The actor for `new?` and `create?` is now anonymous" - but no acceptance criterion retires them, criterion 4 lands the new owner on a group page, and criterion 6 retires `/users/new` and `/users` by name while saying nothing about groups. Removing them would not have removed the capability, since criterion 7 already has confirmation resolve an existing address through `find_or_create_by!`: it would have turned a button into logging out, submitting the form, waiting for mail, opening the link and confirming, once per group. That is the reason, rather than the missing button. The whole justification for deferring creation is that nothing should be written for an address nobody has proven they control, and a signed-in user's address is proven by the session they are holding, so routing them through the confirm loop applies the rule to the one case it does not cover. The two paths therefore divide cleanly, as `## Decisions` records, which is also why `docs/AUTHORIZATION.md` gains a second act rather than a second door. If an app-scoped approval step lands, `groups#create` is the path that gains an approval gate rather than the path that disappears: a signed-in owner asking for a fourth group is exactly who an approver wants in the queue, and they can be put there without being logged out first.
- **Where does the pending group name live: a `purpose` enum on `sign_in_tokens`, a table of its own, or nowhere because the records are created eagerly?** A table of its own. Settled by the owner in the terminal, 2026-09-02. Eager creation was raised first and is rejected on `users.email` being unique: when the submitted address already has an account the form has only two branches, `find_or_create_by!`, which attaches a stranger-named group to a real person's account and mails them a link about it, or `create!`, which raises on the duplicate and so answers differently, reopening the account-existence oracle ADR 0004 spends a section closing. It would also rewrite five of the eight acceptance criteria and turn an owed sweep of inert token rows into a destructive job on `users` and `groups`. The `purpose` enum is rejected for the trap named under `## Decisions`. The owner's further reason for the table is recorded because it constrains nothing today and would be expensive to rediscover: a `sign_ups` row is a request to start a group, which is what an approval step would approve, so approval is a state column here rather than a flag on `groups` and a hidden-group scope threaded through every policy. Which order approval would take is deliberately not decided, because the two orders want different columns - confirm-then-approve keeps the row as shaped and gives the confirmation page nobody to sign in, while approve-then-confirm mints the token late and needs `token_digest` and `expires_at` nullable - and one migration relaxing two `NOT NULL`s is cheaper than guessing now.
