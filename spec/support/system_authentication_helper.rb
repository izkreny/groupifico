module SystemAuthenticationHelper
  # The default. Everything in this application except authentication itself sits behind a session,
  # so a browser pass through the sign-in cycle would be a cost every spec in the suite pays, and
  # the suite is meant to grow to one spec per view and per flow. The signed value is the one
  # `AuthenticationHelper` already computes, so the cookie's signing scheme lives in one place.
  def sign_in_as(user)
    session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |jar|
      jar.signed[:session_id] = session.id
      page.driver.set_cookie("session_id", jar[:session_id])
    end

    session
  end

  # For a spec whose subject *is* authentication. Mints a token, follows the link the email would
  # carry and presses the button that spends it, which is the whole passwordless cycle through the
  # real controllers.
  def sign_in_through_the_browser(user)
    visit sign_in_path(token: SignInToken.mint(user))
    click_button "Sign in"
  end
end
