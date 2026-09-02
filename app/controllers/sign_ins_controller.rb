class SignInsController < ApplicationController
  include TokenFromQueryString

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

  allow_unauthenticated_access only: %i[ show create ]
  before_action :refuse_authenticated
  before_action :hold_sign_in_token, only: :show
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  # Renders, and spends nothing. Company mail filters open every link in a message before the
  # recipient does, so this GET is as likely to be a scanner as a person: it may not spend the
  # token and it may not start a session. ADR 0004's `The emailed link never authenticates` is
  # where that decision lives.
  def show
  end

  def create
    user = SignInToken.redeem!(token_from_session(SignInToken))

    start_new_session_for user

    # The root, always. Nothing records where somebody was bounced from, deliberately, and
    # `request_authentication` carries why.
    redirect_to root_url
  rescue SignInToken::InvalidToken
    redirect_to new_session_path, alert: INVALID_LINK
  end

  private
    def hold_sign_in_token
      @sign_in_token = hold_token_from_query_string(SignInToken, refused_to: new_session_path, alert: INVALID_LINK)
    end
end
