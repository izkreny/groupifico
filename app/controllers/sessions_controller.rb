class SessionsController < ApplicationController
  # Signing in has no user to authorize against, so this skip is permanent. It names its actions for
  # the same reason allow_unauthenticated_access does: an action added here later must not inherit
  # an exemption nobody chose for it.
  skip_verify_authorized only: %i[ new create ]
  # TODO(#172): remove when SessionPolicy lands. `destroy` runs with a session and a Current.user,
  # so it has something to authorize against and is only exempt until it has a policy.
  skip_verify_authorized only: :destroy

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
