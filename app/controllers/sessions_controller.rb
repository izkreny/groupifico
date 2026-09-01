class SessionsController < ApplicationController
  # Permanent, all three, and for two different reasons.
  #
  # Asking for a sign-in link has no user to authorize against yet. Signing out has one, and still
  # nothing to decide: `resource :session` is singular, so the route is DELETE /session with no id
  # in it, and `terminate_session` destroys `Current.session` - the record named by the caller's own
  # signed cookie, never by the request. There is no way to point this action at somebody else's
  # session, so a policy here would have one possible input and one possible answer. Having
  # something to authorize against is not the same as having a decision to make.
  #
  # A session-management screen would change that - revoking another device is DELETE /sessions/:id,
  # the user names the record, and a policy becomes necessary immediately. That is a different route
  # and a different action, and this skip names its actions precisely so the new one cannot inherit
  # an exemption nobody chose for it. Same reason `allow_unauthenticated_access` names its own.
  skip_verify_authorized only: %i[ new create destroy ]

  # The answer to a submitted address, whether or not an account holds it. It names the invitation
  # and not starting a group because somebody who reaches this form believes they already have an
  # account; ADR 0004's `Identical answers, including the clock` has why. The expiry is stated in
  # the email rather than here, where it would be a second copy of one fact.
  LINK_SENT = "Check your inbox: if that address has an account, a sign-in link is on its way. " \
              "If nothing arrives, ask your group's owner or an administrator for an invitation."

  allow_unauthenticated_access only: %i[ new create ]
  before_action :refuse_authenticated, only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  # Enqueued rather than delivered, so a known and an unknown address take the same time to answer.
  # A response identical in status and body is still distinguishable if one path waits on SMTP.
  def create
    if user = User.find_by(email: params[:email].to_s)
      SignInMailer.link(user).deliver_later
    end

    redirect_to new_session_path, notice: LINK_SENT
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
