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
  # key of both would be weaker than either: varying the address would reset a composite counter.
  # The IP limit is the ordinary brute-force bound and catches somebody working through addresses.
  #
  # The address limit is tighter, and is what `sessions#create` needs no equivalent of. That form
  # mails only an address that already has an account, and mails fixed copy; this one mails any
  # address handed to it, carrying up to 250 characters of submitted group name in the body and
  # the link label, so it is a mail-bombing vector as well as a brute-force one. Three per window
  # caps what one address can be sent at twelve messages an hour, and the deliverability half of
  # that matters as much as the victim's inbox: volume to one address is what gets a sending
  # domain blocklisted, which would break sign-up for everybody.
  #
  # Its window is the link's own lifetime rather than a figure picked here, because a second link
  # is useless while the first is still live - so the interval in which a repeat submission means
  # anything is exactly ADR 0004's fifteen minutes. Three leaves room for one send and two "it
  # never arrived", and costs a person who mistypes nothing: a wrong address is a different
  # bucket, and their retries land on the IP limit.
  #
  # The fallback matters: Rails builds the bucket as `[..., name, by].compact.join(":")`, so a
  # blank `by` is a valid key that every address-less POST would share, turning this into one
  # global counter. Falling back to the IP keeps such requests bucketed per caller.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip",
    with: -> { redirect_to new_sign_up_path, alert: "Try again later." }
  rate_limit to: 3, within: SignUp::EXPIRES_IN, only: :create, name: "by-address",
    by: -> { params.dig(:sign_up, :email).to_s.strip.downcase.presence || request.remote_ip },
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
