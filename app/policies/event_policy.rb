class EventPolicy < ApplicationPolicy
  relation_scope { |relation| relation.where(group: user.current_groups) }

  # Every rule an active member reaches, answered exactly as the pre-check used to answer it. They
  # are what keeps this commit behavior-preserving while the pre-check stops granting; the capability
  # table in docs/AUTHORIZATION.md is applied to them next.
  def show?    = true
  def create?  = true
  def edit?    = true
  def update?  = true
  def destroy? = true

  private
    def group_for(record) = record.group
end
