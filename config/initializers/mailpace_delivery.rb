# Swap the class behind the gem's own `:mailpace` symbol rather than registering a second one, so
# `config.action_mailer.mailpace_settings` keeps reaching it: `add_delivery_method` resets
# `mailpace_settings` to its default, and the gem's engine already ran it before
# `action_mailer.set_configs` applied the token.
#
# `to_prepare` rather than the initializer body, because `MailpaceDelivery` is autoloaded from
# `lib`, and a constant captured at boot would go stale on the next reload in development.
Rails.application.config.to_prepare do
  ActionMailer::Base.delivery_methods =
    ActionMailer::Base.delivery_methods.merge(mailpace: MailpaceDelivery).freeze
end
