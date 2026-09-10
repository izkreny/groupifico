module ApplicationHelper
  # `registrations` answers for the section above it: a roster is reached through the Events tab
  # and never leaves it.
  SHELL_SECTIONS = {
    "groups" => :home, "events" => :events, "registrations" => :events, "members" => :members
  }.freeze

  # `create` and `update` sit beside the GET actions because both re-render their form on a failed
  # save, and a reader looking at a form must see no tabs.
  FORM_ACTIONS = %w[ new create edit update duplicate ].freeze

  def shell_section
    SHELL_SECTIONS[controller_name]
  end

  # A `nil` group is ordinary: it covers the screens outside a group and `groups#index`, which
  # maps to `:home` above and has no group of its own.
  def shell_tabs?(group)
    group.present? && shell_section.present? && FORM_ACTIONS.exclude?(action_name)
  end

  # `:home` roots on `show` rather than `index`: a group's home screen is the group itself.
  SECTION_ROOTS = {
    home: %w[ groups show ], events: %w[ events index ], members: %w[ members index ]
  }.freeze

  def pushed_screen?
    shell_section.present? && SECTION_ROOTS[shell_section] != [ controller_name, action_name ]
  end

  def section_root_path(group)
    case shell_section
    when :home    then group_path(group)
    when :events  then group_events_path(group)
    when :members then group_members_path(group)
    end
  end
end
