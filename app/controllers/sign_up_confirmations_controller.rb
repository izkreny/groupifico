class SignUpConfirmationsController < ApplicationController
  include TokenFromQueryString

  # Permanent, both actions, for `SignInsController`'s reason: confirming is how a person becomes
  # authenticated at all, so there is nobody to authorize against yet.
  skip_verify_authorized only: %i[ show create ]

  # Says nothing about which failure it was - unknown digest, already spent, expired, malformed -
  # because telling them apart answers questions the holder of a link must not be able to ask.
  INVALID_LINK = "That link is invalid or has expired. Ask for a new one."

  # The other outcome `SignUp.redeem!` is specified to produce, and it needs its own words: the
  # spend rolled back with the rest of the transaction, so this link is still live and saying it
  # expired would be false.
  UNFINISHED = "Something went wrong finishing your group. Your link still works - try again."

  allow_unauthenticated_access only: %i[ show create ]
  before_action :refuse_authenticated
  before_action :hold_sign_up, only: :show
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_sign_up_path, alert: "Try again later." }

  # Renders, and spends nothing. A mail filter opens this link as often as a person does, so it
  # may not create the account and it may not start a session.
  def show
  end

  # The token is read rather than taken, because one of the two failures below leaves the link
  # live. `start_new_session_for` resets the browser session on the way through, so the success
  # path drops it without being asked; the dead-link path drops it explicitly.
  def create
    member = SignUp.redeem!(held_token(SignUp))

    start_new_session_for member.user

    # The group they just named, which is the whole of what they asked for.
    redirect_to group_url(member.group)
  rescue SignUp::InvalidToken
    token_from_session(SignUp)

    redirect_to new_sign_up_path, alert: INVALID_LINK
  rescue ActiveRecord::RecordInvalid
    # Back to `show`, which re-resolves the link and refuses it if it has since died, so this
    # path needs no second copy of that guard.
    redirect_to sign_up_confirmation_path(token: held_token(SignUp)), alert: UNFINISHED
  end

  private
    def hold_sign_up
      @sign_up = hold_token_from_query_string(SignUp, refused_to: new_sign_up_path, alert: INVALID_LINK)
    end
end
