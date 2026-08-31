class MemberPolicy < ApplicationPolicy
  relation_scope { |relation| relation.where(group: user.current_groups) }

  # The members table in docs/AUTHORIZATION.md, one rule per row. `can_manage?(:members)` matches
  # exactly the three columns those rows mark - `owner`, `administrator` and `members_administrator`
  # - because `Role#grants?` answers true for the first two on every module and for the third on
  # this one. Nothing here names a role.
  def show? = true

  def create?  = membership.can_manage?(:members)
  def edit?    = membership.can_manage?(:members)
  def update?  = membership.can_manage?(:members)
  def destroy? = membership.can_manage?(:members)

  # Granting or revoking a role, and making another member an owner, are the owner's alone: two
  # rows of the table, one rule, because no mechanism could tell the two apart - the owner role is
  # granted the same way every other one is.
  #
  # It is not an action, and no controller action maps to it. `MembersController` asks it as a
  # second question on create and update, whenever the posted roles differ from the ones the member
  # holds, so an administrator may still add a member and change their status.
  def manage_roles? = membership.owner?

  private
    def group_for(record) = record.group
end
