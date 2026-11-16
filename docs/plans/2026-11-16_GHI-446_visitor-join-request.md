> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let visitors ask to join a group (#446)

## Approach

**The email form is its own resource, `JoinRequests::SignInLinksController`, routed as `resource :sign_in_link, only: %i[ show create ], module: :join_requests` inside `resource :join_request`.** `JoinRequestsController#create` is #447's, the signed-in button that adds the pending member, so the signed-out submission cannot share it. `create` takes the email and mails a sign-in link; `show` is the "check your email" page `create` redirects to, so a reload never resubmits (AC2). A dedicated page headed "Check your inbox" is what Mobbin shows almost everywhere (Felt, Better Stack, Wolt, Depop); most of them echo the typed address, which this page leaves out so it stays a stateless GET with nothing to carry across the redirect. Both are unauthenticated by design and refuse a signed-in visitor with `refuse_authenticated`, like `SessionsController`, so they join the permanent `skip_verify_authorized` list.

**`create` resolves the join token before anything else.** The form carries the token in a hidden field, and `JoinLink.find_by_token` raising `ActiveRecord::RecordNotFound` on a dead one means a link turned off between opening the page and submitting it mails nothing and creates nobody (AC5). That diverges from #445's plan, which said #446 would move the token into the browser session: `start_new_session_for` calls `reset_session`, so a session-held token would be gone the moment the mailed link signs the visitor in, and AC7 needs it after that.

**The user is found or created in the request with `User.find_or_create_by(email:)`, per N1 and Fizzy's `JoinCodesController`.** It returns an existing account untouched and an unsaved record carrying presence, length and format errors for a bad address, so the form shows those on the field (AC4) and never shows uniqueness, which would tell a known address from an unknown one (AC3). A persisted user gets `SignInMailer.link(user, return_to: new_join_request_path(token:)).deliver_later`, the existing mail, and `SignInsController#create` already redirects to `return_to` once the link is used (AC7). The insert an unknown address costs is a timing difference ADR 0004's *Identical answers, including the clock* would rather not have; it is milliseconds against the SMTP wait that rule exists for, and taking N1 as written accepts it.

**Two rate limits, copied from `SignUpsController`**: ten per three minutes by IP, and three per `SignInToken::EXPIRES_IN` by the normalised address with the IP as fallback, both redirecting back to the join page with "Try again later." (AC6). The join page draws the form only for a visitor who is not signed in, since what a signed-in visitor sees is #447's (AC1). The join token reaches the log once more, as the value of `return_to` on the mailed link's `GET /sign_in`, because the parameter filter matches keys and not values; it is a shareable link that admits nobody without approval, so this is recorded rather than worked around.

## Steps

- ::S1:: Update `docs/AUTHORIZATION.md`'s join link paragraph to say the page offers a signed-out visitor an email form and that submitting it asks no policy either, add `JoinRequests::SignInLinksController` to the permanent skips in `.agents/rails-style.md`, and add `join_requests/sign_in_links#show`/`#create` to the signed-out surface in `.agents/testing.md`, saying `join_requests#new` now differs between the two contexts
- ::S2:: Route `resource :sign_in_link, only: %i[ show create ], module: :join_requests` inside `resource :join_request` with its `WHY:` comment updated, add `app/controllers/join_requests/sign_in_links_controller.rb` (new) and `app/views/join_requests/sign_in_links/show.html.erb` (new), and `spec/requests/join_requests/sign_in_links_spec.rb` (new) proving: a valid unknown address creates its user, enqueues the sign-in mail carrying the join page as `return_to` and redirects to the check page; an existing user's and an existing member's address get the same redirect and the same mail with no user created; a blank or malformed address answers `422` with the error on the field and mails nothing; a dead token answers `404`, mails nothing and creates nobody; each rate limit refuses at its own threshold on its own key; and a signed-in visitor is redirected to the root from both actions (AC2, AC3, AC4, AC5, AC6)
- ::S3:: Draw the email form on `app/views/join_requests/new.html.erb` for a visitor who is not signed in, set `@user = User.new` for it in `JoinRequestsController#new`, have `create` re-render that page on a refused address, and extend `spec/requests/join_requests_spec.rb` so the signed-out examples assert the form posting to the sign-in link and the signed-in ones assert its absence (AC1, AC4)
- ::S4:: Extend `spec/system/authentication_spec.rb` with the whole round trip, opening a join link, submitting an email, following the mailed link and pressing Sign in, landing on the join page signed in (AC7), and `spec/system/join_page_spec.rb` with the form's refused state and the check page, each accessible in light and dark (AC1, AC2, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-16_GHI-446_visitor-join-request.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-16_GHI-446_visitor-join-request.md docs/AUTHORIZATION.md .agents/rails-style.md .agents/testing.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/join_requests/sign_in_links_spec.rb` passes; the mail examples are seen failing against a `create` that enqueues nothing, the `return_to` example against one that omits it, the existing-address examples against one that builds `User.new(email:)` and saves it, the `422` examples against one that redirects whatever the save returned, the `404` example against one that skips the token lookup, and each rate-limit example against the controller with that limit removed
- ::V4:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; the form examples are seen failing against `main`'s view, and the signed-in absence examples against a view that draws the form for everyone
- ::V5:: `mise exec -- bin/rspec spec/system/authentication_spec.rb spec/system/join_page_spec.rb` passes; the round-trip example is seen failing against a `create` that mails no `return_to`, and the accessibility examples against the form's field rendered without its label
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether the join page and the check page read clearly to somebody who has never used the app, nor whether the timing difference accepted above is one the owner is content to carry; both are the owner's to judge on screen and in this plan.

## Open questions

None.

## Settled

None yet.
