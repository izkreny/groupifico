# The group a nested route names, for the controllers under `/groups/:group_id`.
#
# It assigns two things from one lookup because they have two audiences: `@group` is what the
# views read, in every `group_events_path(@group)` and its siblings, and `Current.group` is what
# `Current.member` needs to answer which membership is acting. A controller that is not nested
# under a group does not include this and leaves both unset.
#
# `include GroupScoped` goes where each controller's `before_action :set_group` used to sit, which
# is what keeps it ahead of `set_event`, `set_member` and `set_registration`.
module GroupScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_group
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
      Current.group = @group
    end
end
