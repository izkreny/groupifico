# Who the styleguide's member switcher may sign in as. The switch signs in as a user by id, so this keeps it to the seeded sample members rather than every account the database holds.
#
# Skips both membership pre-checks, as `AddressPolicy` does: the developer switching is rarely a member of the styleguide group, and the question is about the member being switched to, never about the acting user's place in a group.
class Styleguides::SessionPolicy < ApplicationPolicy
  skip_pre_check :verify_membership!, :verify_active_membership!

  def create? = record.group.name == StyleguidesController::GROUP_NAME
end
