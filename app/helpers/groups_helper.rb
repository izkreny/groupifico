module GroupsHelper
  # The segmented control's order is frame 2e's, not the enum's. The enum lists `general` first
  # because it is what `Brand` answers for an unbranded domain; the control reads better with the
  # two named types first and the catch-all last.
  SEGMENT_ORDER = %w[ choir band general ].freeze

  # Read off the enum rather than off the order above, so a type added to `Group` reaches the
  # control on its own. It lands last until somebody places it, which is the failure worth having:
  # a hand-written list would drop it silently, and the only screen that sets the attribute would
  # be the last place anyone looked.
  def group_type_choices
    Group.group_types.keys
      .sort_by { SEGMENT_ORDER.index(it) || SEGMENT_ORDER.length }
      .map { [ it.capitalize, it ] }
  end
end
