module MembersHelper
  def member_statuses
    Member.statuses.keys
  end
end
