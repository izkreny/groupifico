# The styleguide's member switcher: signs in as one of the styleguide group's members, so the page draws what that member's policies allow.
class Styleguides::SessionsController < ApplicationController
  # WHY: the route is drawn only in development and test, and this refuses anywhere else as well, so a route that ever reaches it in production still signs nobody in. Prepended so a signed-out request gets the same 404 rather than a sign-in redirect that would confirm the action exists.
  prepend_before_action { raise ActionController::RoutingError, "Not Found" unless Rails.env.local? }
  def create
    member = Member.find(params.expect(:member_id))
    authorize! member, with: Styleguides::SessionPolicy

    terminate_session
    start_new_session_for member.user

    redirect_to styleguide_path
  end
end
