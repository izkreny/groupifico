class JoinRequestsController < ApplicationController
  # Permanent: the link is the whole of the visitor's standing, signed in or not, so there is nobody to authorize and nothing a policy could decide. `docs/AUTHORIZATION.md` records it under the records with no group at all.
  skip_verify_authorized only: %i[ new create show ]

  layout "entry"

  allow_unauthenticated_access only: %i[ new create show ]

  # WHY: sign-up's two limits and its reasons, in `SignUpsController`: the address limit is what stops this form mailing one inbox without end, its window is the emailed link's own lifetime, and an address-less submission falls back to the IP so a blank key never becomes one counter every caller shares.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip",
    with: -> { redirect_to new_join_request_path(token: params[:token]), alert: "Try again later." }
  rate_limit to: 3, within: JoinRequest::EXPIRES_IN, only: :create, name: "by-address",
    by: -> { params.dig(:join_request, :email).to_s.strip.downcase.presence || request.remote_ip },
    with: -> { redirect_to new_join_request_path(token: params[:token]), alert: "Try again later." }

  # WHY: every action resolves the token its own request carries, the form posting it back in a hidden field, so a page opened in one tab submits for the group it named whatever another tab opened since; a link that is off, regenerated, unknown or malformed answers the 404 a missing record does, on every action alike.
  before_action :set_join_link

  def new
    @join_request = JoinRequest.new
  end

  # WHY: validated here and recorded in the job, as `SignUpsController#create` does, so nothing is written and nothing is looked up before the address is proven, and the answer cannot differ by whether a user or a member already holds it.
  def create
    @join_request = JoinRequest.new(join_request_params.merge(join_link: @join_link))

    if @join_request.valid?
      JoinRequestMailer.link(@join_link.id, **@join_request.slice(:email, :first_name, :last_name, :mobile_phone).symbolize_keys).deliver_later

      redirect_to join_request_path(token: params[:token]), flash: { sent_to: @join_request.email }
    else
      render :new, status: :unprocessable_content
    end
  end

  # WHY: the address a submission leaves in the flash is the only sign one happened, so without it the page would say a link is on its way when none is; the form is where such a visitor belongs.
  def show
    redirect_to new_join_request_path(token: params[:token]) unless flash[:sent_to]
  end

  private
    def set_join_link
      @join_link = JoinLink.find_by_token(params[:token]) or raise ActiveRecord::RecordNotFound
      @group     = @join_link.group
    end

    def join_request_params
      params.expect(join_request: [ :email, :first_name, :last_name, :mobile_phone ])
    end
end
