class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # This application has no `current_user`; the acting user is reached through `Current.session`.
  authorize :user, through: -> { Current.user }

  # Raises ActionPolicy::UnauthorizedAction when an action completes without an authorize! or
  # authorized_scope call, so a forgotten check fails loudly instead of silently permitting.
  verify_authorized

  rescue_from ActionPolicy::Unauthorized, with: :deny_access

  private
    # Shaped so a future rescue can branch on ex.result.all_details, e.g. to return 404 for a
    # non-member and 403 for a member with the wrong role, decided by the policy that denied.
    def deny_access(ex)
      head :forbidden
    end
end
