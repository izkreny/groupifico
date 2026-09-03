# The gem raises only when a non-200 response body carries an `error` or `errors` key, which
# MailPace's own 4xx bodies do. Any other shape - HTML from an edge, a redirect, a differently
# built 429 - falls through `Mailpace::DeliveryMethod#handle_response` and reports a success that
# never happened. Passwordless email is the only way into this application, so a swallowed
# delivery is indistinguishable from a broken sign-in and leaves nothing behind to find it by.
class MailpaceDelivery < Mailpace::DeliveryMethod
  def deliver!(mail)
    response = super

    # `handle_response` returns the response on a 200 and raises on a body it recognises as an
    # error, so nil is left meaning exactly one thing: a status it did neither for.
    raise Mailpace::DeliveryError, "MAILPACE Error: the API answered a status the gem does not recognise, so the message was not accepted" if response.nil?

    response
  end
end
