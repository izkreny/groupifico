class SignUpsController < ApplicationController
  # Permanent, both actions, and for the reason `UsersController`'s retired pair no longer has to
  # argue: there is no actor to authorize until this flow has created one. `GroupPolicy#create?`
  # keeps sole ownership of the one authorization question either route to a group asks, and this
  # route does not reach it.
  skip_verify_authorized only: %i[ new create ]

  # The answer to a submitted address, whether or not an account holds it. `POST /sign_up` writes
  # nothing at all, so there is nothing here for a duplicate to answer differently about. The
  # expiry is stated in the email rather than here, where it would be a second copy of one fact.
  LINK_SENT = "Check your inbox: a link to finish starting your group is on its way."

  allow_unauthenticated_access only: %i[ new create ]
  before_action :refuse_authenticated

  # Two limits rather than one composite key, because they answer different attacks and a single
  # key of both would be weaker than either. The IP limit is the default and catches somebody
  # working through addresses; the address limit is what `sessions#create` needs no equivalent of,
  # since this form mails any address handed to it and is therefore a mail-bombing vector as well
  # as a brute-force one. Varying the address would reset a composite counter.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip",
    with: -> { redirect_to new_sign_up_path, alert: "Try again later." }
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-address",
    by: -> { params.dig(:sign_up, :email).to_s.strip.downcase },
    with: -> { redirect_to new_sign_up_path, alert: "Try again later." }

  def new
    @sign_up = SignUp.new
  end

  # Validated here and recorded in the job, so the submission itself writes nothing. The check is
  # not belt-and-braces: the row comes into existence inside `SignUpMailer#link`, so an invalid
  # submission that reached the queue would raise in the background after this person had already
  # been told to check their inbox.
  def create
    @sign_up = SignUp.new(sign_up_params)

    if @sign_up.valid?
      SignUpMailer.link(@sign_up.email, @sign_up.group_name).deliver_later

      redirect_to new_sign_up_path, notice: LINK_SENT
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def sign_up_params
      params.expect(sign_up: [ :email, :group_name ])
    end
end
