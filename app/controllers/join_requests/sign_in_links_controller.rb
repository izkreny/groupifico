class JoinRequests::SignInLinksController < ApplicationController
  # WHY: permanent, both actions, since there is nobody signed in to authorize and the join link is the visitor's whole standing, as on `JoinRequestsController#new`; nothing here touches the group, because the mailed link only signs somebody in. `docs/AUTHORIZATION.md` records it beside that page.
  skip_verify_authorized only: %i[ show create ]

  layout "entry"

  allow_unauthenticated_access only: %i[ show create ]
  before_action :refuse_authenticated

  # WHY: the two limits and the address key's IP fallback are `SignUpsController`'s, for the reasons it gives there: this form too mails any address handed to it.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip",
    with: -> { redirect_to new_join_request_path(token: params[:token]), alert: "Try again later." }
  rate_limit to: 3, within: SignInToken::EXPIRES_IN, only: :create, name: "by-address",
    by: -> { params.expect(user: [ :email ])[:email].to_s.strip.downcase.presence || request.remote_ip },
    with: -> { redirect_to new_join_request_path(token: params[:token]), alert: "Try again later." }

  before_action :set_group, only: :create

  def show
  end

  # WHY: found or created in the request, never built and saved, so an address that already has an account comes back as that account rather than as a uniqueness error, and the answer cannot tell the two apart; the one uniqueness error left is the request that lost a race for a new address, answered alike and mailing nothing, since the winner mailed that inbox.
  def create
    @user = User.find_or_create_by(email: params.expect(user: [ :email ])[:email])

    if @user.persisted? || @user.errors.of_kind?(:email, :taken)
      SignInMailer.link(@user, return_to: new_join_request_path(token: params[:token])).deliver_later if @user.persisted?

      redirect_to join_request_sign_in_link_path
    else
      render "join_requests/new", status: :unprocessable_content
    end
  end

  private
    # WHY: resolved before anything is written or mailed, so a link turned off after its page was opened answers the same 404 the page itself would.
    def set_group
      @group = JoinLink.find_by_token(params[:token])&.group
      raise ActiveRecord::RecordNotFound unless @group
    end
end
