namespace :mailpace do
  desc "Send one real sign-in mail through MailPace to prove the credential (development only)"
  task :smoke, [ :email ] => :environment do |_task, args|
    # Development is the only environment that can reach MailPace. `config/environments/test.rb`
    # pins the delivery method to `:test`, and `spec/rails_helper.rb` closes the net with WebMock,
    # so no spec can cover what this task exists to check.
    abort "mailpace:smoke is development only; production already delivers via :mailpace." unless Rails.env.development?

    email = args[:email]
    abort "Usage: bin/rails 'mailpace:smoke[you@example.com]'" if email.blank?

    # Development configures no delivery method at all, so both of these are the task's to set.
    # `raise_delivery_errors` above all: development turns it off, which would swallow a rejected
    # token and let this task report success on a message MailPace never accepted.
    ActionMailer::Base.delivery_method       = :mailpace
    ActionMailer::Base.mailpace_settings     = { api_token: Rails.application.credentials.mailpace_api_token }
    ActionMailer::Base.raise_delivery_errors = true

    # A real mail needs a real user, because the token is minted against one. Creating it is safe
    # here in a way it would not be elsewhere: the development database is disposable, and the
    # link this sends points at `localhost` per that environment's `default_url_options`.
    user = User.find_or_create_by!(email: email)

    SignInMailer.link(user).deliver_now

    puts "Delivered a sign-in mail to #{user.email}."
  end
end
