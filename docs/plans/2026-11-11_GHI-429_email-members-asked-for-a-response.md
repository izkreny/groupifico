> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: email members asked for a response (#429)

## Approach

`Registration#request_response` is the one place a held place moves to `response_requested`, and every request path in N2 funnels through it, so it is where the email is sent: once the place has moved, it enqueues `RegistrationMailer.response_requested` inside `ActiveRecord.after_all_transactions_commit`. A model callback on the status change is not used, because `RegistrationsController#update` lets a manager post `response_requested` straight onto a row, a paused member's included, and a callback would mail them against AC4; seeds and factories never call `request_response`, so they mail nobody, which is N3's concern about `MemberMailer.welcome`. The send waits for commit because `enqueue_after_transaction_commit` is off in this Rails 8.1 by default and production's Solid Queue writes to its own database, so a `deliver_later` inside `fill_list`'s transaction would survive the rollback AC5 forbids.

`RegistrationMailer` (new) is its own mailer, for the reason `MemberMailer` gives: a different subject, link and copy, and its argument is the registration. The mail names the group and the event, prints the start with `EventsHelper#event_schedule_range` in the application's fixed `Time.zone`, and links to `group_event_url` with no token; a signed-out member following it is bounced to the ordinary sign-in form, which is all of AC6 here, and landing back on the event after sign-in is #430's. Resending is #431's.

## Steps

- ::S1:: Add `app/mailers/registration_mailer.rb` (new) with `response_requested(registration)`, its views `app/views/registration_mailer/response_requested.html.erb` (new) and `app/views/registration_mailer/response_requested.text.erb` (new) in the voice of `MemberMailer.welcome`, and `spec/mailers/registration_mailer_spec.rb` (new) asserting the recipient, a subject naming the event, the group, the start and the event's URL in the body, and that a member who has never signed in is addressed and no sign-in token is minted (AC1, AC6)
- ::S2:: Make `Registration#request_response` enqueue that mail after the outermost transaction commits, only when the place moved, and rewrite its comment and the one on `Event#request_all_responses` to say where the notification hangs
- ::S3:: Extend `spec/models/registration_spec.rb` under `#request_response`: one mail for a moved place (AC1), none for an answered place, a place already requested, or a paused or inactive member (AC4, AC13), and none when the surrounding transaction rolls back (AC5)
- ::S4:: Extend `spec/models/event_spec.rb` under `#request_all_responses` and `#fill_list`: one mail to each member whose place moved and nobody else, members without a place, with an answer or already asked included (AC2, AC3, AC4, AC13), and none when `fill_list` rolls back part way (AC5)
- ::S5:: Extend `spec/requests/registrations/response_requests_spec.rb`, `spec/requests/events/response_requests_spec.rb` and the `POST /groups/:group_id/events` examples in `spec/requests/events_spec.rb` so each press enqueues the mail and each refused press enqueues none (AC1, AC2, AC3, AC5)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-11_GHI-429_email-members-asked-for-a-response.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-11_GHI-429_email-members-asked-for-a-response.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/mailers/registration_mailer_spec.rb` passes, each example seen failing first against a mailer whose body or subject leaves out the fact it asserts
- ::V4:: `mise exec -- bin/rspec spec/models/registration_spec.rb spec/models/event_spec.rb` passes; the mailing examples are seen failing against `Registration#request_response` as it is on `main`, the no-mail examples for answered, paused, inactive and already-asked places against a mutation that mails before the `reserved? && member.active?` guard, and the rollback examples against a mutation that calls `deliver_later` directly instead of after commit
- ::V5:: `mise exec -- bin/rspec spec/requests/registrations/response_requests_spec.rb spec/requests/events/response_requests_spec.rb spec/requests/events_spec.rb` passes; the enqueue examples are seen failing against `main`, the refused-press examples against a mutation that mails before the policy check
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the new views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove who is mailed and what the mail carries, not how it reads: AC7, the subject and copy reading as a request in the voice of `MemberMailer.welcome`, is the owner's to judge from the mail's text in the diff.

## Open questions

None.

## Settled

None yet.
