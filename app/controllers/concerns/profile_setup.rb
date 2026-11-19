# A signed-in user whose profile lacks a first name or a mobile does nothing but fill them in. Keyed on the missing data rather than on a first sign-in, so a member imported before the mobile was required is sent too.
module ProfileSetup
  extend ActiveSupport::Concern

  included do
    before_action :require_profile_setup
  end

  class_methods do
    def allow_unset_profile(**options)
      skip_before_action :require_profile_setup, **options
    end
  end

  private
    # WHY: `authenticated?` rather than `Current.user`, because on an `allow_unauthenticated_access` action such as the join page nothing has resumed the session yet; only a GET has a page to come back to, as `request_authentication` gives.
    def require_profile_setup
      if authenticated? && !Current.user.profile.setup?
        redirect_to edit_user_profile_path(return_to: (request.fullpath if request.get?)),
          info: "Add your first name and mobile to continue.",
          status: :see_other
      end
    end
end
