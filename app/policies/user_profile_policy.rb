class UserProfilePolicy < ApplicationPolicy
  # A user profile has no group at all - it is scoped to the acting user's own identity, which
  # `edit?` already answers directly. Skipped rather than answered with a guess, same as
  # AddressPolicy.
  skip_pre_check :verify_membership!, :verify_active_membership!

  alias_rule :update?, to: :edit?

  def edit? = record.user_id == user.id
end
