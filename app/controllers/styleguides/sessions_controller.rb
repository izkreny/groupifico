# The styleguide's member switcher: signs in as a member's user, so the page draws what that member's policies allow.
class Styleguides::SessionsController < ApplicationController
  # WHY: the route is drawn only in development and test, and this refuses anywhere else as well, so a route that ever reaches it in production still signs nobody in. Prepended so a signed-out request gets the same 404 rather than a sign-in redirect that would confirm the action exists.
  prepend_before_action { raise ActionController::RoutingError, "Not Found" unless Rails.env.local? }

  # Permanent, settled by the owner on #369. The environment guard above and sign-in are the whole gate, so there is no decision for a policy to make: a developer's tool may sign in as any member. Named actions rather than a bare skip, for the reason `StyleguidesController` gives.
  skip_verify_authorized only: %i[ create ]

  def create
    member = Member.find(params.expect(:member_id))

    terminate_session
    start_new_session_for member.user

    redirect_to styleguide_path
  end
end
