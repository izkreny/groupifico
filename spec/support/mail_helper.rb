module MailHelper
  # The sign-in link in the one mail delivered to `email`, read from the decoded text part: a link
  # carrying a destination is long enough for the encoded body's quoted-printable soft breaks to
  # split it.
  def mailed_sign_in_link(email)
    URI.parse(ActionMailer::Base.deliveries.select { it.to == [ email ] }.sole.text_part.decoded[%r{https?://\S+?/sign_in\?\S+}])
  end
end
