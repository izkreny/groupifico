> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: replace mailpace-rails with a net/http delivery method (#308)

## Approach

`MailpaceDelivery` in `lib/mailpace_delivery.rb` stops subclassing the gem's class and becomes the whole delivery method: one JSON `POST` to `https://app.mailpace.com/api/v1/send` over `Net::HTTP`, with the token in the `MailPace-Server-Token` header. A 200 returns the response and every other status raises `MailpaceDelivery::Error`, which replaces `Mailpace::DeliveryError`. The message carries MailPace's own reason when the body is JSON, in either shape its API reference documents: `error`, a string, or `errors`, a hash of field to messages, rendered as `to is invalid`. Any other body, the HTML 502 from an edge and the bodyless 500 included, raises with the status code instead. A network failure raises whatever `Net::HTTP` raises, unwrapped, because a failed job naming `Net::ReadTimeout` says more than a wrapper would.

The request carries what this application's mailers set: `from`, `to`, `subject`, `htmlbody` and `textbody`. The sender is read from the header field, because `mail.from` returns the bare address and drops the display name. A multipart mail sends its HTML and text parts, and a single-part mail sends its one body under the key its content type names. Each body is decoded to UTF-8 before it is serialised, since a Croatian mail is quoted-printable on the wire. The open and read timeouts are set to ten seconds: `Net::HTTP` defaults to sixty each, which parks a Solid Queue worker for a minute on a hung API.

The gem's remaining fields are not ported: `cc`, `bcc`, `replyto`, the threading headers, `list_unsubscribe`, attachments, tags and the idempotency key. No mailer here sets any of them, so each would be code with no caller and no spec. The cost is that a mailer which later sets one has to add it to the delivery method too, and the class says so in a comment.

Registration is the part with a trap in it. `config.action_mailer.mailpace_settings` in `config/environments/production.rb` works only while `ActionMailer::Base` already has a `mailpace_settings=` writer when `action_mailer.set_configs` applies the options, and `add_delivery_method` is what defines it. The gem's engine did that; `config/initializers/mailpace_delivery.rb` (delete) only ever swapped the class afterwards. With the gem removed and that initializer left as it is, a production boot dies on `NoMethodError: undefined method 'mailpace_settings=' for class ActionMailer::Base`, while development and test boot fine because neither sets the option. That was run, not inferred, and it is the red state of the production-boot gate below.

Boot order decides where the registration can live, as read from `railties` and `actionmailer` 8.1.4 and tried on this branch. A file in `config/initializers` runs after `action_mailer.set_configs` has queued its load hook, so a hook registered there runs second and is too late. An `initializer` block ordered `before: "action_mailer.set_configs"` runs before the once autoloader is set up, so it cannot reach a constant in `lib`: it raised `NameError: uninitialized constant MailpaceDelivery`. What works is a load hook registered in the body of `config/application.rb`, which is evaluated before any initializer runs: `ActiveSupport.on_load(:action_mailer) { add_delivery_method :mailpace, MailpaceDelivery }`. It runs first when `ActionMailer::Base` loads, and by then the autoloaders are up.

`ActionMailer::Base` is not reloadable, so the class it holds must not be either, and `config.autoload_lib` becomes `config.autoload_lib_once`. That is the mechanism Rails ships for a class in `lib` that framework code holds on to, and it is what makes the `to_prepare` swap unnecessary. It covers all of `lib`, so `lib/chromium.rb` stops reloading in development as well. Nothing a development server serves calls either file, so nothing is lost. The production boot with the hook and the once autoloader in place was run and exits 0 with the class registered and the token key present.

`bundle remove mailpace-rails` takes `httparty`, `multi_xml` and `csv` out of `Gemfile.lock` with it and leaves `mini_mime`, which `mail` and `capybara` still need. The gem's Action Mailbox ingress route, `POST /rails/action_mailbox/mailpace/inbound_emails`, goes with its engine and needs nothing done. The `delivery_method` and `mailpace_settings` lines in `config/environments/production.rb` stay as they are; the comment above them loses the clause citing the gem's README, which would point at nothing.

`spec/lib/mailpace_delivery_spec.rb` asserts the request body with WebMock rather than only stubbing a status, because the body is what the criteria are about. The multipart example sends a real `SignInMailer.link` message, so the shape under test is the one Action Mailer builds.

## Steps

- Add the JSON-error example to `spec/lib/mailpace_delivery_spec.rb`, a 400 answering `{"error":"Invalid API Token"}`, and watch it fail against the gem with `ArgumentError: unknown keyword: quirks_mode`, which is the regression the issue states
- Rewrite `lib/mailpace_delivery.rb` as a standalone delivery method over `Net::HTTP`, raising `MailpaceDelivery::Error` on every status other than 200
- Register it from `config/application.rb` with the `action_mailer` load hook, switch `config.autoload_lib` to `config.autoload_lib_once`, and delete `config/initializers/mailpace_delivery.rb` (delete)
- Run `bundle remove mailpace-rails`, drop the comment line above it in `Gemfile`, and check the `Gemfile.lock` diff by eye: only `mailpace-rails`, `httparty`, `multi_xml` and `csv` leave
- Finish the spec: the registration, the token header, a multipart mail, an HTML-only and a text-only mail, a non-ASCII body, the sender's display name, the `error` and `errors` bodies, the HTML 502, the bodyless 500, and the accepted 200
- Trim the gem's-README clause from the comment in `config/environments/production.rb`, leaving the `delivery_method` and `mailpace_settings` lines untouched
- Run the gates below, each watched failing first where it is new

## Verification

- `bin/ci` fails only at *Tests: System*: `test "$(bin/ci 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep '^❌' | cut -d' ' -f2,3)" = "$(printf 'Tests: System\nContinuous Integration')"` exits 0, having been seen to exit 1 on an extra failed step
- The system suite fails only on #299's examples: `test "$(bin/rspec spec/system --format failures | cut -d: -f1,2 | LC_ALL=C sort -u | tr '\n' ' ')" = "./spec/system/address_edit_page_spec.rb:70 ./spec/system/me_spec.rb:128 ./spec/system/member_edit_page_spec.rb:23 "` exits 0, having been seen to exit 1 on a fourth failure
- Production boots with the delivery method registered and its settings applied: `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'exit(ActionMailer::Base.delivery_methods[:mailpace] == MailpaceDelivery && ActionMailer::Base.mailpace_settings.key?(:api_token))'` exits 0, having been seen to exit 1 with the gem removed and the registration not yet moved
- The gems are gone: `grep -qwE 'mailpace-rails|httparty|multi_xml|csv' Gemfile Gemfile.lock` exits 1, having been seen to exit 0 on `main`
- Production's `delivery_method` and `mailpace_settings` lines are unchanged: `grep -qxF '  config.action_mailer.delivery_method   = :mailpace' config/environments/production.rb && grep -qxF '  config.action_mailer.mailpace_settings = { api_token: Rails.application.credentials.mailpace_api_token }' config/environments/production.rb` exits 0, having been seen to exit 1 against a copy with one line altered
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' --plans docs/plans docs/plans/2026-09-30_GHI-308_net-http-mailpace-delivery.md` exits 0

No gate here sends a message. WebMock closes the net in the suite, so what MailPace actually answers to this request body is unproven until `mailpace:smoke` runs in development, once with the real token and once with a deliberately wrong one. That run sends real mail from the owner's account, so it is the owner's to make, and the issue's criterion for it stays unticked until then. The production-boot gate runs by hand and nothing in `bin/ci` repeats it, so a later change that breaks the registration order would pass every spec. The response bodies are taken from MailPace's API reference rather than from recorded traffic, and a reason that arrives in a shape the reference does not list still raises, with the status code in place of the reason.

## Open questions

None.
