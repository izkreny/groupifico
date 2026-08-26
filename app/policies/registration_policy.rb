class RegistrationPolicy < ApplicationPolicy
  relation_scope { |relation| relation.joins(:event).merge(Event.where(group: user.groups)) }

  private
    def group_for(record) = record.event.group
end
