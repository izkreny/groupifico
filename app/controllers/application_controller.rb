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

  # Counts authorized_scope calls the way verify_authorized counts authorize! calls, and raises
  # when an index completes without one. Bare it would also fire on show, edit, update and destroy,
  # which scope nothing, so it is constrained to the one action where an unscoped collection is
  # the leak.
  #
  # `if:` rather than `only:`: `only:` makes Rails check every controller for a literal `index`
  # method and raise if one is missing (`raise_on_missing_callback_actions`, on in this app), which
  # would break every controller with no index action at all - `SessionsController`, `PasswordsController`,
  # and the rest. A runtime condition asks no such question; it is simply never true for them.
  verify_authorized_scoped if: -> { action_name == "index" }

  rescue_from ActionPolicy::Unauthorized, with: :deny_access
  # AuthorizationContextMissing is a sibling of Unauthorized rather than a descendant, so the line
  # above cannot catch it. It is raised when a policy is built with no Current.user, which reads as
  # a refusal rather than a fault, so it lands on the same handler.
  rescue_from ActionPolicy::AuthorizationContextMissing, with: :deny_access

  private
    # Branches on the denial's own reason rather than on the controller. A policy that denies for
    # non-membership sets details[:not_found] before calling deny!, per ApplicationPolicy - that is
    # the record does not exist for this user, so it gets 404 rather than a 403 that would confirm
    # the id exists. Everything else - a paused member attempting to write - belongs and is refused
    # with a redirect carrying an alert, so a denied link or Turbo submission does not look broken.
    #
    # root_path rather than redirect_back_or_to, deliberately. The refusing page is almost always
    # the referer - a paused member submits the edit form they were allowed to read - so redirecting
    # back lands them on the form that just refused them, which is indistinguishable from the button
    # doing nothing. Caught in a browser, not by a spec: a request spec sends no Referer, so
    # redirect_back_or_to fell through to root_path there and looked correct.
    #
    # ActionPolicy::AuthorizationContextMissing carries no result at all; in practice it never
    # reaches here, since require_authentication redirects before any policy runs, but it is routed
    # through the same handler and falls to the redirect branch rather than raising a second time.
    def deny_access(exception)
      if exception.respond_to?(:result) && exception.result.all_details[:not_found]
        head :not_found
      else
        redirect_to root_path, alert: "You are not allowed to do that.", status: :see_other
      end
    end
end
