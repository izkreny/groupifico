class SessionsController < ApplicationController
  # Permanent, all three, and for two different reasons.
  #
  # Signing in has no user to authorize against yet. Signing out has one, and still nothing to
  # decide: `resource :session` is singular, so the route is DELETE /session with no id in it, and
  # `terminate_session` destroys `Current.session` - the record named by the caller's own signed
  # cookie, never by the request. There is no way to point this action at somebody else's session,
  # so a policy here would have one possible input and one possible answer. Having something to
  # authorize against is not the same as having a decision to make.
  #
  # A session-management screen would change that - revoking another device is DELETE /sessions/:id,
  # the user names the record, and a policy becomes necessary immediately. That is a different route
  # and a different action, and this skip names its actions precisely so the new one cannot inherit
  # an exemption nobody chose for it. Same reason `allow_unauthenticated_access` names its own.
  skip_verify_authorized only: %i[ new create destroy ]

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
