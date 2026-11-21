class JoinRequestsController < ApplicationController
  # Permanent: the link is the whole of the visitor's standing, signed in or not, so there is nobody to authorize and nothing a policy could decide. `create` adds only a pending member, who reaches nothing of the group until somebody who may add a person approves them. `docs/AUTHORIZATION.md` records it under the records with no group at all.
  skip_verify_authorized only: %i[ new create ]

  layout "entry"

  allow_unauthenticated_access only: :new

  before_action :set_group

  def new
    if authenticated?
      @member = @group.members.find_by(user: Current.user)
    else
      @user = User.new
    end
  end

  # WHY: found before it is created, so a second press or a page left open in another tab leaves a membership that already exists as it is, whatever its status, rather than bringing back a member who left; no bang, because two presses in flight at once both find nothing and the later one's create is refused by the membership the earlier one just wrote, and that refusal is answered with the same join page, which shows the request waiting; `status: :pending` is stated because a member is created `active` by default.
  def create
    @group.members.create_with(status: :pending).find_or_create_by(user: Current.user)

    redirect_to new_join_request_path(token: params[:token])
  end

  private
    # WHY: a link that is off, regenerated, unknown or malformed raises what a missing record raises, so it renders the same 404 page and tells its holder nothing about which it was; resolved before `create` writes anything.
    def set_group
      @group = JoinLink.find_by_token(params[:token])&.group
      raise ActiveRecord::RecordNotFound unless @group
    end
end
