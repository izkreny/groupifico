# The half of redeeming an emailed link that both flows do identically: take the token out of the
# query string, prove it resolves to something live, and move it into the browser session so the
# button on the page submits nothing but a form.
#
# It is shared rather than written twice because both halves are security measures that would
# otherwise be reimplemented. The token leaves the query string because only the query string is
# filtered out of the log, so a token repeated on the POST would be a second chance to leak it.
# And it is resolved on the GET rather than only at the POST, because the page has to name what it
# would do - a link nobody sent you is otherwise indistinguishable from your own, and pressing the
# button hands the outcome to whoever did send it. A link that resolves to nothing gets the page
# refused instead of a page with nobody's name on it. Both are ADR 0004's.
#
# The browser-session key comes off the model, so an outstanding sign-in link and an outstanding
# sign-up link in one browser cannot overwrite each other.
module TokenFromQueryString
  extend ActiveSupport::Concern

  private
    # Returns the resolved record for the caller to name in its own ivar, since the view reads it
    # by a name that means something on that page.
    def hold_token_from_query_string(model, refused_to:, alert:)
      model.pending(params[:token]).tap do |pending|
        if pending
          session[token_key(model)] = params[:token]
        else
          redirect_to refused_to, alert: alert
        end
      end
    end

    # Read once and gone, on the failure path as well as the success one: leaving it behind would
    # hand a second attempt to whoever gets the browser session next.
    def token_from_session(model)
      session.delete(token_key(model))
    end

    # The same read without the drop, for a caller that has a failure the link survives - the
    # holder is meant to try again, so dropping the token here would strand a live link.
    def held_token(model)
      session[token_key(model)]
    end

    def token_key(model) = model.name.underscore.to_sym
end
