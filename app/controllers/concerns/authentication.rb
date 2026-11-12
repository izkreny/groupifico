module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :return_to
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def return_to
      url_from(params[:return_to])
    end

    def require_authentication
      resume_session || request_authentication
    end

    # The other half of `require_authentication`, for the routes that only make sense to a visitor
    # who is not signed in. Rodauth's equivalent hook defaults to a no-op and its own release notes
    # call that out as an account-confusion risk that a set hook had already prevented in a real
    # vulnerability; ADR 0004 quotes them.
    def refuse_authenticated
      redirect_to root_path, notice: "You are already signed in." if authenticated?
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # WHY: the destination rides the query string into the emailed link and never the browser session, which signing in resets and which nothing distinguishes from one an attacker planted; a path rather than a URL because the mail's host comes from mailer config, not the brand domain the request arrived on; only a GET has a page to return to, and the root is where sign-in lands anyway.
    def request_authentication
      redirect_to new_session_path(return_to: (request.fullpath if request.get? && request.path != root_path))
    end

    # `reset_session` first, so a browser session planted before sign-in does not survive it. The
    # signed cookie this method sets is what authenticates, so a fixed session id grants no login
    # on its own; what a planted session would reach is whatever else the application keeps there.
    # ADR 0004 records why the landing page is no longer among those things.
    def start_new_session_for(user)
      reset_session

      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
