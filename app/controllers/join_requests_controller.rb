class JoinRequestsController < ApplicationController
  # Permanent: the link is the whole of the visitor's standing, signed in or not, so there is nobody to authorize and nothing a policy could decide. `docs/AUTHORIZATION.md` records it under the records with no group at all.
  skip_verify_authorized only: %i[ new create show ]

  layout "entry"

  allow_unauthenticated_access only: %i[ new create show ]

  # WHY: sign-up's two limits and its reasons, in `SignUpsController`: the address limit is what stops this form mailing one inbox without end, its window is the emailed link's own lifetime, and an address-less submission falls back to the IP so a blank key never becomes one counter every caller shares.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip",
    with: -> { redirect_to new_join_request_path(token: session[:join_link_token]), alert: "Try again later." }
  rate_limit to: 3, within: JoinRequest::EXPIRES_IN, only: :create, name: "by-address",
    by: -> { params.dig(:join_request, :email).to_s.strip.downcase.presence || request.remote_ip },
    with: -> { redirect_to new_join_request_path(token: session[:join_link_token]), alert: "Try again later." }

  before_action :hold_join_link, only: :new
  before_action :resume_join_link, only: %i[ create show ]

  def new
    @join_request = JoinRequest.new
  end

  # WHY: validated here and recorded in the job, as `SignUpsController#create` does, so nothing is written and nothing is looked up before the address is proven, and the answer cannot differ by whether a user or a member already holds it.
  def create
    @join_request = JoinRequest.new(join_request_params.merge(join_link: @join_link))

    if @join_request.valid?
      JoinRequestMailer.link(@join_link.id, **@join_request.slice(:email, :first_name, :last_name, :mobile_phone).symbolize_keys).deliver_later

      redirect_to join_request_path, flash: { sent_to: @join_request.email }
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  private
    # WHY: the token moves from the query string into the browser session, so the form's submission carries none and a link that is off, regenerated, unknown or malformed answers the 404 a missing record does, on every action alike.
    def hold_join_link
      find_join_link(params[:token])
      session[:join_link_token] = params[:token]
    end

    def resume_join_link
      find_join_link(session[:join_link_token])
    end

    def find_join_link(token)
      @join_link = JoinLink.find_by_token(token) or raise ActiveRecord::RecordNotFound
      @group     = @join_link.group
    end

    def join_request_params
      params.expect(join_request: [ :email, :first_name, :last_name, :mobile_phone ])
    end
end
