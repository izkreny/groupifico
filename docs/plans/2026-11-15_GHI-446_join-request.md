> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let visitors ask to join a group (#446)

## Approach

**A join request is a record that carries an emailed token, exactly as a sign-up is.** `JoinRequest` includes `Redeemable`, belongs to the `JoinLink` it came through by a cascading foreign key, and holds the four submitted details: `email`, `first_name`, `last_name` and `mobile_phone`, with the lengths and normalization `User` and `UserProfile` use. Belonging to the link rather than the group is what #445's plan set up for #447's AC6: turning a link off or regenerating it deletes every request made through it. Like `SignUp`, the row is minted inside the mailer, so `POST /join` validates and enqueues and writes nothing, and `JoinRequestMailer#link` takes the link's id rather than the record, so a link retired between the submission and the job sends no mail instead of failing the job.

**The join link's token travels from the page to the form in the browser session**, as #445's plan assigned to this issue: `new` resolves the token from the query string, keeps it in the session and draws the form; `create` resolves the held token again, so a link turned off after the page opened answers the same `404` as an unknown one (AC5). A valid submission redirects to `show`, the "check your email" page, at `GET /join`, which names the group and the address the link went to, carried in the flash; the copy is identical whatever the address is, and nothing at submission looks up a user, a member or a profile, so no answer can differ between them (AC3). An invalid one re-renders the form with each field's message under it through `AppFormBuilder#field` (AC4).

**Both of sign-up's rate limits, on `create`** (AC6): ten per IP in three minutes, and three per address within `Redeemable::EXPIRES_IN`, falling back to the IP for an address-less submission so a blank key never becomes one shared counter. A refused submission redirects back to the form with "Try again later."

**The mailed link needs a route, and the confirmation page is #447's**, so this branch draws the smallest page #445 drew for the join link: `resource :join_request_confirmation, only: :show` and a `JoinRequestConfirmationsController#show` that names the group a live request belongs to and answers `404` for any other token, with no button and no session hold. #447 adds the button, the redemption and its refusals; until then a confirmation link opens a page that says what it would join and does nothing.

Stated assumptions, each the owner's to overturn in review:

- The mobile phone is required and checked only for shape, an optional `+` then at least six characters of digits, spaces, dots, dashes and parentheses, within `UserProfile`'s fifty, because `UserProfile` carries no format rule yet and its uniqueness is #447's collision to handle at confirmation, never a submission error.
- The "check your email" page names the submitted address, as Preply, Quizlet and Slack do on Mobbin, so a typo is visible before the mail fails to arrive.

## Steps

- ::S1:: Extend `docs/AUTHORIZATION.md`'s "Opening a join link asks no policy" paragraph to the form, the "check your email" page and the confirmation page; add `JoinRequestConfirmationsController` to the permanent skips in `.agents/rails-style.md`; add `join_requests#create`, `join_requests#show` and `join_request_confirmations#show` to the signed-out surface in `.agents/testing.md` (AC1, AC2, AC5)
- ::S2:: Add a migration creating `join_requests` with a cascading `join_link_id`, the four details as not-null columns, `token_digest` under a unique index, `expires_at` and `consumed_at`; add `app/models/join_request.rb` (new) including `Redeemable`, with presence, length and format validations and email normalization; a factory in `spec/factories/join_requests.rb` (new); and `spec/models/join_request_spec.rb` (new) proving each detail is required, the email and mobile formats are refused, the email is normalized, and deleting the join link deletes its requests (AC4)
- ::S3:: Route `resource :join_request_confirmation, only: :show`, add `app/controllers/join_request_confirmations_controller.rb` (new) and `app/views/join_request_confirmations/show.html.erb` (new) on the `entry` layout, and `spec/requests/join_request_confirmations_spec.rb` (new) proving a live token names the group signed in and signed out, and a spent, expired, unknown or missing token answers `404` (AC2)
- ::S4:: Add `app/mailers/join_request_mailer.rb` (new) with `link`, its views `app/views/join_request_mailer/link.html.erb` (new) and `app/views/join_request_mailer/link.text.erb` (new), and `spec/mailers/join_request_mailer_spec.rb` (new) proving the mail goes to the submitted address, names the group, records the request as it builds, carries the token in the query string, sends a token that resolves to that request, and sends nothing for a link retired before it builds (AC2)
- ::S5:: Route `resource :join_request, only: %i[ new create show ], path: "join"`; in `JoinRequestsController` hold the token on `new` and draw the form, add `create` with both rate limits and `show`; extend `app/views/join_requests/new.html.erb` with the form and add `app/views/join_requests/show.html.erb` (new); extend `spec/requests/join_requests_spec.rb` proving, signed in and signed out, the form renders, a valid submission enqueues the mail, writes no request, user, member or profile, and lands on a page naming the group and the address, an existing user's and an existing member's address land on the same page, a missing or invalid detail re-renders with its field's message and enqueues nothing, a link turned off or regenerated before submitting answers `404`, and the fourth submission for one address and the eleventh from one IP are refused (AC1, AC2, AC3, AC4, AC5, AC6)
- ::S6:: Extend `spec/system/join_page_spec.rb` with submitting the form and landing on the "check your email" page, and a refused submission whose field errors paint, each screen accessible in light and dark (AC1, AC2, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-15_GHI-446_join-request.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-15_GHI-446_join-request.md docs/AUTHORIZATION.md .agents/rails-style.md .agents/testing.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/join_request_spec.rb` passes; each validation example is seen failing with its validation removed, the normalization example with `normalizes` removed, and the cascade example against a migration whose foreign key has no `on_delete: :cascade`
- ::V4:: `mise exec -- bin/rspec spec/requests/join_request_confirmations_spec.rb` passes; the `404` examples are seen failing against a `show` that renders whether or not `JoinRequest.pending` found a row
- ::V5:: `mise exec -- bin/rspec spec/mailers/join_request_mailer_spec.rb` passes; the recording and token examples are seen failing against a `link` that mints nothing, and the retired-link example against a `link` that mails without checking the link still exists
- ::V6:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; every new example is seen failing on the pre-branch code, which has no `create` or `show` route, and additionally the `404` examples on `create` against a `create` that skips resolving the held token, the identical-page examples against a `show` that adds "already" when a user holds the address, the writes-nothing example against a `create` that saves the request, and the rate-limit examples with each `rate_limit` removed in turn
- ::V7:: `mise exec -- bin/rspec spec/system/join_page_spec.rb` passes; the new examples are seen failing against a `new` view with no form
- ::V8:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V9:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether the form's and the mail's copy read as clear to a visitor who has never heard of Groupifico, nor whether the two stated assumptions above are the ones the owner wants; both are the owner's to judge on the screenshots and in the diff.

## Open questions

None.

## Settled

None yet.
