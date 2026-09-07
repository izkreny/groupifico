module AuthenticationHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    cookies["session_id"] = AuthenticationHelper.signed_session_cookie(Current.session)
  end

  # The one place a spec learns how the session cookie is signed. The request suite sets it into
  # `cookies` and the system suite hands it to the browser's own cookie jar, so renaming the cookie
  # or moving from `signed` to `encrypted` breaks both layers at once rather than leaving the
  # browser suite red against a green request suite.
  def self.signed_session_cookie(session)
    ActionDispatch::TestRequest.create.cookie_jar.tap do |jar|
      jar.signed[:session_id] = session.id
    end[:session_id]
  end
end
