# Its own mailer rather than a third method on an existing one, for the reason `SignUpMailer` gives:
# a different recipient, a different link and different copy. What a person added by address gets
# is an invitation, which they answer with Join or Decline on the group's join page.
class MemberMailer < ApplicationMailer
  # Mints nothing. The link is the ordinary sign-in form with the address and the join page in its
  # query string, which ADR 0004's `The invitation link is not a credential` records as no
  # credential at all, so there is no row, no digest and nothing to expire. The query string rather
  # than a path segment is what lets `filter_parameter_logging.rb` redact the address from the log,
  # and `return_to` is what #430's sign-in cycle carries into the emailed sign-in link.
  def invitation(member)
    @group = member.group
    @email = member.email

    mail subject: "You are invited to join #{@group.name}", to: @email
  end
end
