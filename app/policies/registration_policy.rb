class RegistrationPolicy < ApplicationPolicy
  relation_scope { |relation| relation.joins(:event).merge(Event.where(group: user.current_groups)) }

  private
    def group_for(record) = record.event.group
end
