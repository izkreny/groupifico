class MemberPolicy < ApplicationPolicy
  # A pending member is listed to the owners of their group alone, per docs/AUTHORIZATION.md. Owners rather than active owners, because seeing one is a read a paused owner keeps.
  relation_scope do |relation|
    relation.where(group: user.current_groups).where.not(status: :pending)
      .or(relation.where(group: user.current_memberships.owners.select(:group_id)))
  end

  pre_check :conceal_pending_members!

  # The members table in docs/AUTHORIZATION.md, one rule per row. `can_manage?(:members)` matches
  # exactly the three columns those rows mark - `owner`, `administrator` and `members_administrator`
  # - because `Role#grants?` answers true for the first two on every module and for the third on
  # this one. Nothing here names a role.
  def show? = true

  def create?  = membership.can_manage?(:members)
  def edit?    = membership.can_manage?(:members)
  def update?  = membership.can_manage?(:members)
  def destroy? = membership.can_manage?(:members)

  # Seeing who has left the group and who has not signed in yet, for the three columns that add a person. A read, so it stays out of `WRITE_RULES` and a paused members administrator keeps it while losing every write.
  def oversee? = membership.can_manage?(:members)

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

    # A pending member does not exist for anybody but an owner, who gets every read and no write: leaving `pending` is approving or declining, never a status written on the member form, per docs/AUTHORIZATION.md. Runs after the inherited pre-checks, so `membership` is already known to be current.
    def conceal_pending_members!
      return unless record.pending?
      return deny! if membership.owner? && write_rule?
      return if membership.owner?

      details[:not_found] = true
      deny!(:not_found)
    end
end
