class UserProfilePolicy < ApplicationPolicy
  def show? = record.user_id == user.id
  def edit? = show?
  def update? = show?
end
