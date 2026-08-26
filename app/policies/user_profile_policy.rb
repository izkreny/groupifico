class UserProfilePolicy < ApplicationPolicy
  alias_rule :edit?, :update?, to: :show?

  def show? = record.user_id == user.id
end
