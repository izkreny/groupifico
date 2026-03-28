module MembersHelper
  def member_statuses
    Member.statuses.keys
  end

  def member_roles
    Member.roles.keys
  end
end
