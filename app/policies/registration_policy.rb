class RegistrationPolicy < ApplicationPolicy
  relation_scope { |relation| relation.joins(:event).merge(Event.where(group: user.current_groups)) }

  # The registration rows of the events table in docs/AUTHORIZATION.md. Every member sees who is
  # registered and what they answered.
  def show? = true

  # The invitation row, and nobody else's: a registration is something somebody else puts you into,
  # `reserved` or `invited`, and what a member does with it afterwards is answer it. So `own?` is
  # absent here and present on `update?`, which is the row that grants a member their own answer.
  #
  # It reads the same as `manage_answers?` below, which is not a duplicate to fold away: this rule
  # decides an action and that one decides a status, and `update?` already shows them parting.
  def create? = membership.can_manage?(:events) || manages_event?

  # Changing somebody else's answer is not the manager's, deliberately: filling an event is their
  # job, overruling an answer is not. So `manages_event?` is absent here and present above.
  #
  # `edit?` says the same thing under its own name rather than aliasing `update?`, for the reason
  # GroupPolicy's own comment gives: an alias renames the running rule and the read/write split
  # stops seeing a read.
  def edit?   = own? || membership.can_manage?(:events)
  def update? = own? || membership.can_manage?(:events)

  # Taking a registration away is the three roles', and nobody withdraws their own: the answer to
  # not attending is `no`, which `update?` already covers.
  def destroy? = membership.can_manage?(:events)

  # Which statuses the actor may write, asked by the controller alongside the rules above, because a
  # posted status is not on the record when `update?` runs. A member may say `yes`, `maybe` or `no`
  # about themselves and nothing else; `reserved` and `invited` belong to whoever fills the event.
  def manage_answers? = membership.can_manage?(:events) || manages_event?

  private
    def group_for(record) = record.event.group

    def own? = record.member_id == membership.id

    def manages_event? = record.event.manager_id == membership.id
end
