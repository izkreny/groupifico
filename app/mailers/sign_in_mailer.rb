class SignInMailer < ApplicationMailer
  # The token is minted here rather than by the caller so that `deliver_later` serialises a `User`
  # global id into the job payload instead of the raw token. A minted token passed as an argument
  # would be written into `solid_queue_jobs.arguments`, which is the kind of datastore the row's
  # digest column exists to keep it out of. It also starts the fifteen minutes when the mail is
  # actually built rather than when the request came in.
  def link(user)
    @user  = user
    @token = SignInToken.mint(user)

    mail subject: "Your sign-in link", to: user.email
  end
end
