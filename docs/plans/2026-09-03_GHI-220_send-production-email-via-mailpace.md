> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: send production email via mailpace (#220)

## Approach

Production has no delivery method at all, so Action Mailer falls back to its own defaults, `:smtp` at `localhost:25`, and there is no MTA in the app container. Add the `mailpace-rails` gem, point production at its delivery method, and give the mailers a real sender.

The gem is an engine whose only initializer calls `ActionMailer::Base.add_delivery_method(:mailpace, Mailpace::DeliveryMethod)`, ordered `before: 'action_mailer.set_configs'`, so a `config.action_mailer.mailpace_settings` written in an environment file is picked up the way `smtp_settings` would be. `config/application.rb` already loads `rails/all`, so the gem's `require 'action_mailbox/engine'` pulls in nothing this app does not already have, and its inbound-mail controller stays unrouted because `config.action_mailbox.ingress` is never set.

The configuration goes in `config/environments/production.rb`, replacing the commented `smtp_settings` block. The gem's README says to put it in `config/application.rb`, which is wrong for this app: that file applies to every environment, and while `config/environments/test.rb:43` would override the delivery method back to `:test`, development would start sending real mail to real addresses.

`raise_delivery_errors` is left alone. Its production default is already `true`, and writing a value equal to its default adds a line to the diff that says nothing. That default is what turns a bad token into a visible failed execution: `ActionMailer::MailDeliveryJob` declares no `retry_on`, `ApplicationMailer` declares no `rescue_from`, and `app/jobs/application_job.rb` has its `retry_on` line commented out, so the gem's `Mailpace::DeliveryError` reaches Solid Queue on the first attempt.

One credential key, `mailpace_api_token`, flat. MailPace issues one token per domain and #221 records what a second domain would need, but there is one domain today and a nested hash with one entry is a shape built for a future that is not scheduled.

## Steps

- Add `gem "mailpace-rails"` to the `Gemfile`, unpinned and in the main group, matching how `action_policy` and the rest are declared, and commit the resulting `Gemfile.lock`
- Owner step: add `mailpace_api_token` through `bin/rails credentials:edit`, using a token rotated after the original was pasted into a chat transcript
- Replace the commented `smtp_settings` block in `config/environments/production.rb` with `config.action_mailer.delivery_method = :mailpace` and `config.action_mailer.mailpace_settings = { api_token: Rails.application.credentials.mailpace_api_token }`
- Set `default from:` in `app/mailers/application_mailer.rb` to the address settled under `## Open questions`, replacing `from@example.com`
- Verify DKIM for `chorifico.com` in the MailPace dashboard, which the service requires before it accepts any message
- Send one message for real, then send one with a deliberately wrong token and watch it fail

## Verification

- `bin/ci` passes, which puts the new gem and its `httparty` dependency through `bin/bundler-audit`
- A live send with the real token completes without raising and the message appears in the MailPace dashboard
- The same send with a deliberately wrong token raises `Mailpace::DeliveryError`, proving the failure path rather than assuming it

The gates cannot see whether the message reaches an inbox rather than a spam folder, which is a judgement about DKIM, SPF and DMARC on `chorifico.com` rather than something with an exit code. They also cannot see that the link inside a delivered sign-in mail still points at `example.com`: `config/environments/production.rb:61` is #76's business and stays untouched here, so end-to-end sign-in through a real inbox is only provable once that lands.

## Open questions

- **Bare address or display name?** `default from: "hello@chorifico.com"` is what #220 asks for, but `"Chorifico <hello@chorifico.com>"` is what a recipient would see in a mail client. The gem preserves the display name, verified by reading `mail.header[:from].element.addresses.first.to_s` back as `"Chorifico <hello@chorifico.com>"`, so both work and this is a product choice.
- **Where does the live send happen?** `RAILS_ENV=production bin/rails runner` locally proves the real `config/environments/production.rb` path but needs a production database in the checkout; `bin/kamal app exec` proves it on the real container but depends on #76.
- **Does the mail copy change with the sender?** `app/views/sign_in_mailer/link.html.erb:2` reads "Sign in to Groupifico" while the sender becomes `hello@chorifico.com`. Leaving it is a visible inconsistency at beta; changing it is scope this issue did not ask for.

## Settled

None yet.
