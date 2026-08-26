class MemberPolicy < ApplicationPolicy
  relation_scope { |relation| relation.where(group: user.groups) }

  private
    def group_for(record) = record.group
end
