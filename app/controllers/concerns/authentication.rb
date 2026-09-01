module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
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

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    # `reset_session` first, so a browser session planted before sign-in does not survive it. The
    # signed cookie this method sets is what authenticates, so a fixed session id grants no login
    # on its own; what it reaches is `session[:return_to_after_authenticating]`, which a planted
    # session could otherwise use to steer where the person lands. Reading that destination before
    # calling this would hand the steer straight back, so callers read it afterwards or not at all.
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
