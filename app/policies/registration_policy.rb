class RegistrationPolicy < ApplicationPolicy
  # The statuses that are an answer. `reserved` and `invited` are the other two, and they are what
  # somebody else puts you into rather than something you say about yourself.
  ANSWERS = %w[ yes maybe no ].freeze

  relation_scope { |relation| relation.joins(:event).merge(Event.where(group: user.current_groups)) }

  # The registration rows of the events table in docs/AUTHORIZATION.md. Every member sees who is
  # registered and what they answered.
  def show? = true

  # Answering for yourself is every member's; registering somebody else is the three roles', and
  # the event's manager may do it for their own event - that is the invitation row.
  def create? = own? || membership.can_manage?(:events) || manages_event?

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

    # A registration with nobody on it yet is nobody else's: `new` builds one before the form has
    # chosen a member, and every member may answer for themselves, so refusing there would refuse
    # them the only form they have. Nothing escapes through it - `create` asks again with the posted
    # member_id, and a registration saved without one fails `belongs_to :member` anyway.
    def own? = record.member_id.nil? || record.member_id == membership.id

    def manages_event? = record.event.manager_id == membership.id
end
