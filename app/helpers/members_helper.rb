module MembersHelper
  def member_statuses
    Member.statuses.keys
  end

  # `AppFormBuilder#field` draws a `:select` from a choices list, so a collection reaches it mapped
  # rather than through `collection_select`, whose html options sit in a fourth positional argument
  # the builder would have to special-case a second time.
  def member_choices(members)
    members.map { [ it.full_name, it.id ] }
  end
end
