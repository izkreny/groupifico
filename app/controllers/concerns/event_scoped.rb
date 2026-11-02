# The event a nested route names, for the controllers under `/groups/:group_id/events/:event_id`, found within the group so an id from another group answers 404.
#
# `include EventScoped` goes where `include GroupScoped` would, and brings it along, which keeps `set_group` ahead of `set_event` and both ahead of `set_registration`.
module EventScoped
  extend ActiveSupport::Concern
  include GroupScoped

  included do
    before_action :set_event
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end
end
