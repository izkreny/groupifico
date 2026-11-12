module MailHelper
  # WHY: the decoded text part, because a link carrying a destination is long enough for the encoded body's quoted-printable soft breaks to split it.
  def sign_in_link_in(mail)
    URI.parse(mail.text_part.decoded[%r{https?://\S+?/sign_in\?\S+}])
  end

  def mailed_sign_in_link(email)
    sign_in_link_in(ActionMailer::Base.deliveries.select { it.to == [ email ] }.sole)
  end
end
