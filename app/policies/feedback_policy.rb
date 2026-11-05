class FeedbackPolicy < ApplicationPolicy
  # WHY: feedback belongs to an account rather than a group, so the membership pre-checks have nothing to ask.
  skip_pre_check :verify_membership!, :verify_active_membership!

  def create? = true

  def show? = record.user_id == user.id
end
