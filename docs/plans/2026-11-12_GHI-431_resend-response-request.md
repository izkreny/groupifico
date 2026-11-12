> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: resend a response request (#431)

## Approach

The resend is its own method, `Registration#request_response_again`, rather than a widened `Registration#request_response`, because `Event#request_all_responses` and `fill_list` call `request_response` on every row and would then re-mail everyone already asked. It moves only a `response_requested` row of an active member on an event still open to answers, `touch`es it so `updated_at` is the new request's time per N2, and enqueues the same `RegistrationMailer.response_requested` inside `ActiveRecord.after_all_transactions_commit`, as `request_response` does and for the same reason. `touch` skips validations, so those guards are the method's own.

`Registrations::ResponseRequestsController#create` keeps its one route and branches on the row: a requested row is asked again, any other row goes through `request_response` as today. The "already requested" notice on a requested row becomes a notice that the member was asked again.

The tinted plane on a requested row becomes the trigger of a `<dialog>`, through `shared/confirm_scope` and `app/javascript/controllers/dialog_controller.js` as the confirm sheet uses them: the plane stays an ordinary `button_to` posting the request, the controller opens the dialog instead, and the dialog's Send again submits that same form. `shared/confirm_sheet` is not reused, because it is built for a delete, so the dialog is a new partial, `app/views/events/_request_again.html.erb` (new), one per requested row with ids from `dom_id`. With JavaScript off the plane posts the resend straight away, the trade the confirm sheet already makes. The plane keeps its aria-label, `Response requested from {name}`.

The last-sent time is absolute, in the format the event screens already use (`EventsHelper::DATE_FORMAT` and `TIME_FORMAT`), through a new public `EventsHelper#response_requested_at(registration)`; Mobbin has no "last sent" dialog, and its nearest, HoneyBook's scheduled-send notice, states the time absolutely too. The copy follows the issue: a title asking whether to ask the member again, a line saying when they were last asked, a Close button and a Send again button. AC2's "the dialog then shows the new time" is read as the dialog reopened after the redirect that Send again lands on, since the redirect closes it.

## Steps

- ::S1:: Add `Registration#request_response_again` with its guards, the `touch` and the mail after commit, and extend `spec/models/registration_spec.rb` with a `#request_response_again` group: one mail and a moved `updated_at` for a requested row under `travel_to` (AC2), nothing for a reserved or answered row, a paused or inactive member, or a concluded or canceled event, and no mail when the surrounding transaction rolls back
- ::S2:: Branch `Registrations::ResponseRequestsController#create` onto it and extend `spec/requests/registrations/response_requests_spec.rb`: a press on a requested row enqueues the mail, keeps the row `response_requested`, moves `updated_at` and says the member was asked again, replacing the "already requested" example for that row (AC2)
- ::S3:: Add `EventsHelper#response_requested_at`, rewriting the comment on the private `day_and_time` that says no view states an instant, and add `app/views/events/_request_again.html.erb` (new), rendered by the roster for a requested row in place of the bare plane, with the roster's header comment rewritten to say what the tinted plane now does
- ::S4:: Extend `spec/requests/events_spec.rb` under `GET /groups/:group_id/events/:id`: a requested row's dialog carries the hand-written last-sent time, a Send again button submitting the plane's form, and a Close button, and a reserved row draws no dialog (AC1)
- ::S5:: Extend `spec/system/event_detail_spec.rb`: pressing the tinted plane opens the dialog and the open page is accessible (AC1), Close shuts it and leaves the row's `updated_at` as it was (AC3), and Send again lands back on the event and the reopened dialog shows the new time under `travel_to` (AC2)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-12_GHI-431_resend-response-request.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-12_GHI-431_resend-response-request.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/registration_spec.rb` passes; the mailing and `updated_at` examples are seen failing against a stub `request_response_again` that returns false, the refusal examples against a mutation that drops the `response_requested? && member.active? && event.open_to_answers?` guard, and the rollback example against a mutation that calls `deliver_later` directly instead of after commit
- ::V4:: `mise exec -- bin/rspec spec/requests/registrations/response_requests_spec.rb spec/requests/events_spec.rb` passes; the resend examples are seen failing against the controller as it is on `main`, and the dialog markup examples against the roster as it is on `main`
- ::V5:: `mise exec -- bin/rspec spec/system/event_detail_spec.rb` passes; the open and Send again examples are seen failing against the roster as it is on `main`, and the Close example against a mutation whose Close button submits the plane's form
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The gates prove the dialog opens, closes without sending and sends again; whether its title and line read naturally as a question to ask somebody again is the owner's to judge from the rendered dialog.

## Open questions

None.

## Settled

None yet.
