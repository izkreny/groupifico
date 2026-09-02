# Its own mailer rather than a second method on `SignInMailer`. What the two flows share is the
# credential mechanism in `Redeemable`, not the delivery: this mail takes no user, links to its own
# route and names the group, so one method serving both would branch on whether a group name was
# passed, and a sign-up mail living in a class named for signing in would be a naming lie.
class SignUpMailer < ApplicationMailer
  # The row comes into existence here, which is what makes recording the request and mailing its
  # link one job: `POST /sign_up` returns having written nothing at all. It could not be otherwise
  # even if that were not wanted - the row stores only a digest, so a token minted in the
  # controller could never be recovered to put in the URL. The fifteen minutes therefore start
  # when the mail is built, and the job payload carries two plain strings.
  def link(email, group_name)
    @group_name = group_name
    @token      = SignUp.mint(email: email, group_name: group_name)

    mail subject: "Finish starting your group", to: email
  end
end
