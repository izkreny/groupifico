class UserProfilePolicy < ApplicationPolicy
  # A user profile has no group at all - it is scoped to the acting user's own identity, which
  # `show?` already answers directly. Skipped rather than answered with a guess, same as
  # AddressPolicy.
  skip_pre_check :verify_membership!, :verify_active_membership!

  alias_rule :edit?, :update?, to: :show?

  def show? = record.user_id == user.id
end
