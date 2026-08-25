class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # This application has no `current_user`; the acting user is reached through `Current.session`.
  authorize :user, through: -> { Current.user }

  # Raises ActionPolicy::UnauthorizedAction when an action completes without an authorize! call.
  # It counts authorize! only: authorized_scope bumps a separate counter and does not satisfy this
  # guard, which is why #172 enables verify_authorized_scoped only: :index alongside it.
  #
  # This is an after_action, so it reports a forgotten check rather than preventing one: the action
  # has already run and its writes have committed by the time it raises. It is a tripwire for the
  # window in which controllers still carry skips, not a substitute for authorizing before acting.
  verify_authorized

  rescue_from ActionPolicy::Unauthorized, with: :deny_access

  private
    # Shaped so a future rescue can branch on ex.result.all_details, e.g. to return 404 for a
    # non-member and 403 for a member with the wrong role, decided by the policy that denied.
    def deny_access(ex)
      head :forbidden
    end
end
