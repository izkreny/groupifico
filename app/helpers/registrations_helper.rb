module RegistrationsHelper
  def registration_statuses
    Registration.statuses.keys
  end

  def members_available(group, event)
    group.members - event.attendees
  end
end
