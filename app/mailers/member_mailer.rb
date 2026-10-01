# Its own mailer rather than a third method on an existing one, for the reason `SignUpMailer` gives:
# a different recipient, a different link and different copy. Named for the member rather than for
# an invitation, because an invitation in this application is a `Registration` status.
class MemberMailer < ApplicationMailer
  # Mints nothing. The link is the ordinary sign-in form with the address in its query string,
  # which ADR 0004's `The invitation link is not a credential` records as no credential at all, so
  # there is no row, no digest and nothing to expire. The query string rather than a path segment
  # is what lets `filter_parameter_logging.rb` redact the address from the log.
  def welcome(member)
    @group = member.group
    @email = member.email

    mail subject: "You were added to #{@group.name}", to: @email
  end
end
