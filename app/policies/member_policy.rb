class MemberPolicy < ApplicationPolicy
  relation_scope { |relation| relation.where(group: user.current_groups) }

  private
    def group_for(record) = record.group
end
