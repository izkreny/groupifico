class EventPolicy < ApplicationPolicy
  relation_scope { |relation| relation.where(group: user.current_groups) }

  # The events table in docs/AUTHORIZATION.md, one rule per row. `can_manage?(:events)` matches the
  # three role columns those rows mark; the fourth column, `manager`, is not a role at all and is
  # answered by `manages?` below.
  def show? = true

  # `duplicate` authorizes `create?` rather than a rule of its own, so whoever is refused one is
  # refused the other. A manager is deliberately unmarked here: filling their event is their job,
  # making new ones is not.
  def create?  = membership.can_manage?(:events)
  def destroy? = membership.can_manage?(:events)

  # Editing includes handing the event on, because `manager_id` is an attribute of the event like
  # its status and its location, so no separate rule exists for reassigning it.
  #
  # Spelled out rather than aliased or composed, for the reason GroupPolicy's own comment gives:
  # both routes rename the running rule and a paused member would be refused the form they may
  # read.
  def edit?   = membership.can_manage?(:events) || manages?
  def update? = membership.can_manage?(:events) || manages?

  private
    def group_for(record) = record.group

    # One event, never the group's others. `manager_id` is a per-event grant that no role table can
    # hold, which is why it is a column of its own in the capability table.
    def manages? = record.manager_id == membership.id
end
