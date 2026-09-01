class SignInsController < ApplicationController
  # Permanent, both actions. Redeeming an emailed link is how a person becomes authenticated at
  # all, so there is no signed-in user to authorize against - the argument the deleted
  # `PasswordsController` made for the recovery flow, arriving here with the flow that replaced it.
  # Named actions rather than a bare skip, so an action added later cannot inherit an exemption
  # nobody chose for it - the reason `SessionsController` gives for naming its own.
  skip_verify_authorized only: %i[ show create ]

  # Says nothing about which of the four failures it was - unknown digest, already spent, expired,
  # malformed - because telling them apart answers questions the holder of a link must not be able
  # to ask.
  INVALID_LINK = "That sign-in link is invalid or has expired. Ask for a new one."

  allow_unauthenticated_access
  before_action :refuse_authenticated
  before_action :hold_token_from_query_string, only: :show
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  # Renders, and does nothing else. Company mail filters open every link in a message before the
  # recipient does, so this GET is as likely to be a scanner as a person: it may not spend the
  # token and it may not start a session. ADR 0004's `The emailed link never authenticates` is
  # where that decision lives.
  def show
  end

  def create
    # Read once and gone, on the failure path below as well as on this one.
    user = SignInToken.redeem!(session.delete(:sign_in_token))

    # `start_new_session_for` resets the browser session first, so `after_authentication_url` finds
    # no stored destination and answers with the root. That is the point rather than an oversight:
    # the destination is planted by whoever held this browser session before sign-in, and nothing
    # in the session can tell the person who was bounced off a group page from an attacker who
    # planted the same key. Following a link back to where you were is the thing #139's fresh
    # session criterion gives up, and a link that carries its own destination is the way to get it
    # back later.
    start_new_session_for user
    redirect_to after_authentication_url
  rescue SignInToken::InvalidToken
    redirect_to new_session_path, alert: INVALID_LINK
  end

  private
    # The token arrives in the query string, per ADR 0004, and moves into the browser session so
    # that the button below submits nothing but a form: only the query string is filtered out of
    # the log, and a token repeated on the POST would be a second chance to leak it.
    def hold_token_from_query_string
      if params[:token].present?
        session[:sign_in_token] = params[:token]
      else
        redirect_to new_session_path, alert: INVALID_LINK
      end
    end
end
