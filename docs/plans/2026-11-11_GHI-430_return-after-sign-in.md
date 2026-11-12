> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: return to the page after sign-in (#430)

## Approach

The destination is carried, never stored: every hop between the bounced request and the redemption is a query string or a form field, so nothing touches the browser session that `reset_session` throws away, which is the constraint ADR 0004 names. `request_authentication` redirects a bounced GET to `new_session_path(return_to: request.fullpath)`, a path rather than `request.url` because the mail's host comes from mailer config and not from the brand domain the request arrived on; a bounce from the root carries nothing, since landing on the root is the default and the commonest sign-in URL stays clean, and a non-GET carries nothing, since a redirect can only replay a GET. `sessions/new` carries the value as a hidden field, `SessionsController#create` hands it to `SignInMailer.link(user, return_to:)`, the mail puts it in the link's query string beside `token`, and `sign_ins/show` carries it on the button as a hidden param.

The open-redirect guard is Rails' own `url_from`, which answers a location only when it is a path (`/` but not `//`) or a URL on the request's host, and `nil` otherwise. It sits at the redirect in `SignInsController#create`, `redirect_to url_from(params[:return_to]) || root_url`, because both the link's query string and the hidden field are writable by anybody; `SessionsController#create` passes the value through the same call so an off-site value is never written into a mail, but that is hygiene and not the boundary, and AC2's examples inject the hostile value at the redemption POST so a guard placed only at mail time cannot pass them. Without the guard `load_defaults 8.1` makes an off-site `redirect_to` raise `UnsafeRedirectError`, a 500 rather than the root AC2 asks for.

## Steps

- ::S1:: Make `request_authentication` in `app/controllers/concerns/authentication.rb` redirect a bounced GET other than the root to `new_session_path(return_to: request.fullpath)`, and rewrite its comment, which says it records nowhere to return to, to say the destination rides the query string and why never the session
- ::S2:: Update every signed-out GET example under `spec/requests` that asserts `redirect_to new_session_path` to name the destination it was bounced from, leave the non-GET ones as they are, and add one example each to `spec/requests/groups_spec.rb` showing a bounced non-GET and a bounced root carry no destination
- ::S3:: Carry the destination through the sign-in form: a hidden `return_to` field in `app/views/sessions/new.html.erb` when the form is opened with one, and `SessionsController#create` passing `url_from(params[:return_to])` to `SignInMailer.link`; extend `spec/requests/sessions_spec.rb` so the form carries the value it is opened with, the mail is enqueued with an in-app destination, with none for an off-site one (AC2) and with none from a form opened without one (AC3)
- ::S4:: Give `SignInMailer.link` a `return_to:` keyword defaulting to `nil` that rides the link's query string beside the token in both views, and extend `spec/mailers/sign_in_mailer_spec.rb` so the link carries a given destination and carries no `return_to` key without one
- ::S5:: Carry it from the link page to the redemption: `app/views/sign_ins/show.html.erb` puts the query string's `return_to` on the button as a hidden param, `SignInsController#create` redirects to `url_from(params[:return_to]) || root_url`, and the comments in that action and in `app/controllers/concerns/emailed_link_token.rb` that say the root always and that the button submits nothing but a form are rewritten to match
- ::S6:: Extend `spec/requests/sign_ins_spec.rb`: the link page carries the destination on its button, the redemption lands on an in-app destination (AC1), lands on the root for `https://other.example/x`, `//other.example` and `/\other.example` posted straight at it (AC2), and the existing no-destination example keeps landing on the root (AC3); add one request-level walk that follows every hop - signed-out GET of an event page, the bounced form, the delivered mail's link, the button - and lands on the event page (AC1)
- ::S7:: Extend `spec/system/authentication_spec.rb` with the browser landing: a signed-out member opens an event page, asks for a link on the bounced form, follows the link built from the sign-in mail the form sent, presses the button and is on the event page (AC1)
- ::S8:: Replace ADR 0004's closing sentence in `docs/adr/2026-08-31_passwordless-email-sign-in_0004.md`, which says carrying the destination in the emailed link is a change nobody has scheduled, with what #430 built and where the guard sits

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-11_GHI-430_return-after-sign-in.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-11_GHI-430_return-after-sign-in.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests` passes; the updated bounce examples and the request-level walk are seen failing against `request_authentication` as it is on `main`, and the no-destination examples for a non-GET and the root against a mutation that adds `return_to` to every bounce
- ::V4:: `mise exec -- bin/rspec spec/requests/sessions_spec.rb spec/mailers/sign_in_mailer_spec.rb` passes; the carrying examples are seen failing against `main`, the off-site example against a mutation that passes `params[:return_to]` to the mailer without `url_from`
- ::V5:: `mise exec -- bin/rspec spec/requests/sign_ins_spec.rb` passes; the in-app landing and the button's hidden param are seen failing against `main`, the three off-site examples against a mutation that redirects to `params[:return_to] || root_url`, and the no-destination example against a mutation that redirects to `url_from(params[:return_to]) || edit_user_profile_url`
- ::V6:: `mise exec -- bin/rspec spec/system/authentication_spec.rb` passes, the new example seen failing against `main`
- ::V7:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The gates prove where a sign-in lands, not that the bounced form's URL reads acceptably with a `return_to` in it; that, and whether a bounce from the root should carry one after all, is the owner's to judge.

## Open questions

None.

## Settled

None yet.
