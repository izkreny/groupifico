class JoinRequestsController < ApplicationController
  # Permanent: the link is the whole of the visitor's standing, signed in or not, so there is nobody to authorize and nothing a policy could decide. `docs/AUTHORIZATION.md` records it under the records with no group at all.
  skip_verify_authorized only: :new

  layout "entry"

  allow_unauthenticated_access only: :new

  # WHY: a link that is off, regenerated, unknown or malformed raises what a missing record raises, so it renders the same 404 page and tells its holder nothing about which it was.
  def new
    @group = JoinLink.find_by_token(params[:token])&.group
    raise ActiveRecord::RecordNotFound unless @group
  end
end
