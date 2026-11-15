class JoinRequestConfirmationsController < ApplicationController
  # Permanent: the emailed token is the whole of its holder's standing, signed in or not, so there is nobody to authorize, as on `JoinRequestsController`. `docs/AUTHORIZATION.md` records it beside that controller.
  skip_verify_authorized only: :show

  layout "entry"

  allow_unauthenticated_access only: :show

  # WHY: renders and spends nothing, because a mail filter opens the link as often as a person does; the button that confirms is #447's.
  def show
    @join_request = JoinRequest.pending(params[:token])
    raise ActiveRecord::RecordNotFound unless @join_request
  end
end
