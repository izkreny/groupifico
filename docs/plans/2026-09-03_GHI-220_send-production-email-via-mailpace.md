> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: send production email via mailpace (#220)

## Approach

Production has no delivery method at all, so Action Mailer falls back to its own defaults, `:smtp` at `localhost:25`, and there is no MTA in the app container. Add the `mailpace-rails` gem, point production at its delivery method, and give the mailers a real sender.

The gem is an engine whose only initializer calls `ActionMailer::Base.add_delivery_method(:mailpace, Mailpace::DeliveryMethod)`, ordered `before: 'action_mailer.set_configs'`, so a `config.action_mailer.mailpace_settings` written in an environment file is picked up the way `smtp_settings` would be. `config/application.rb` already loads `rails/all`, so the gem's `require 'action_mailbox/engine'` pulls in nothing this app does not already have, and its inbound-mail controller stays unrouted because `config.action_mailbox.ingress` is never set.

The configuration goes in `config/environments/production.rb`, replacing the commented `smtp_settings` block. The gem's README says to put it in `config/application.rb`, which is wrong for this app: that file applies to every environment, and while `config/environments/test.rb:43` would override the delivery method back to `:test`, development would start sending real mail to real addresses.

`raise_delivery_errors` is left alone. Its production default is already `true`, and writing a value equal to its default adds a line to the diff that says nothing. That default is what turns a bad token into a visible failed execution: `ActionMailer::MailDeliveryJob` declares no `retry_on`, `ApplicationMailer` declares no `rescue_from`, and `app/jobs/application_job.rb` has its `retry_on` line commented out, so the gem's `Mailpace::DeliveryError` reaches Solid Queue on the first attempt.

One credential key, `mailpace_api_token`, flat. MailPace issues one token per domain and #221 records what a second domain would need, but there is one domain today and a nested hash with one entry is a shape built for a future that is not scheduled.

Everything a recipient sees about mail belongs in this branch rather than trailing behind it, so the sender's brand and the mail's own copy change together: a message signed `hello@chorifico.com` whose body reads "Sign in to Groupifico" is inconsistent in the one place a user is deciding whether to trust the link. That is the two `sign_in_mailer` views and nothing else, since `sign_up_mailer` names the group rather than the product and `app/views/layouts/mailer.html.erb` carries no brand at all. The remaining `Groupifico` strings live in the application chrome, not in mail, and stay for #223: Groupifico is the platform's canonical name, so that issue brands the chrome per domain rather than renaming anything.

The live send gets a rake task rather than a one-off console recipe, so it is repeatable and reviewable. It runs in development because that is the only environment that can reach MailPace: `config/environments/test.rb:43` pins `delivery_method = :test`, and `spec/rails_helper.rb:16` calls `WebMock.disable_net_connect!(allow_localhost: true)`, so no spec can send. Development needs the delivery method set explicitly in the task, since `config/environments/development.rb` sets none and only turns `raise_delivery_errors` off.

## Steps

- Add `gem "mailpace-rails"` to the `Gemfile`, unpinned and in the main group, matching how `action_policy` and the rest are declared, and commit the resulting `Gemfile.lock`
- Owner step: add `mailpace_api_token` through `bin/rails credentials:edit`, using a rotated token
- Replace the commented `smtp_settings` block in `config/environments/production.rb` with `config.action_mailer.delivery_method = :mailpace` and `config.action_mailer.mailpace_settings = { api_token: Rails.application.credentials.mailpace_api_token }`
- Set `default from:` in `app/mailers/application_mailer.rb` to `"Chorifico <hello@chorifico.com>"`, replacing `from@example.com`
- Replace "Groupifico" with "Chorifico" in `app/views/sign_in_mailer/link.text.erb` and `app/views/sign_in_mailer/link.html.erb`, so the copy matches the sender
- Add `lib/tasks/mailpace.rake` exposing a `mailpace:smoke` task that takes a recipient address, sets `:mailpace` and the credential explicitly, and delivers one message now
- Verify DKIM for `chorifico.com` in the MailPace dashboard, which the service requires before it accepts any message
- Run the smoke task for real, then run it with a deliberately wrong token and watch it fail

## Verification

- `bin/ci` passes, which puts the new gem and the three dependencies it brings, `httparty`, `multi_xml` and `csv`, through `bin/bundler-audit`
- `bin/rails mailpace:smoke` in development delivers to a real address without raising, which the gem only allows on an HTTP 200
- The same task with a deliberately wrong token raises `Mailpace::DeliveryError`, proving the failure path rather than assuming it
- The delivered message reads "Chorifico" in both the html and text parts and is signed `Chorifico <hello@chorifico.com>`

The gates cannot see whether the message is listed in the MailPace dashboard, nor whether it reaches an inbox rather than a spam folder, which is a judgement about DKIM, SPF and DMARC on `chorifico.com` rather than something with an exit code. They also cannot see that the link inside a delivered sign-in mail still points at `example.com`: `config/environments/production.rb:61` is #76's business and stays untouched here, so end-to-end sign-in through a real inbox is only provable once that lands. Nor do they prove the production path itself, since the smoke task configures the delivery method in development rather than reading `config/environments/production.rb`.

## Open questions

None.

## Settled

- **Bare address or display name?** `"Chorifico <hello@chorifico.com>"`, with the display name a recipient actually sees, rather than the bare address #220 asked for; the gem preserves it, verified by reading `mail.header[:from].element.addresses.first.to_s` back. Settled in a review thread on this pull request, 2026-09-03.
- **Where does the live send happen?** In development, through a `mailpace:smoke` rake task, rather than under `RAILS_ENV=production` locally or through `bin/kamal app exec`; test is excluded by its own `delivery_method = :test` and by WebMock, and a task in development waits on neither a production database nor #76. Settled in a review thread on this pull request, 2026-09-03.
- **Does the mail copy change with the sender?** Yes, in this branch: everything a recipient sees about mail lands together, so the two `sign_in_mailer` views drop "Groupifico" for "Chorifico". The application chrome keeps its `Groupifico` strings, which #223 now covers. Settled in a review thread on this pull request, 2026-09-03.
