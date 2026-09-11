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

  # `groups#new` is the one pushed screen outside any group, so the Home section has a second root:
  # with no group to show, the index is what the back chevron leads up to. The group is what tells
  # the two apart, which is why both helpers below are asked for it. Without the distinction,
  # `groups#index` answers pushed too and draws a chevron pointing at itself - masked until now
  # only by the layout refusing to ask for a back target without a group.
  GROUPLESS_HOME_ROOT = %w[ groups index ].freeze

  def pushed_screen?(group)
    return false if shell_section.blank?

    section_root(group) != [ controller_name, action_name ]
  end

  def section_root_path(group)
    case shell_section
    when :home    then group ? group_path(group) : groups_path
    when :events  then group_events_path(group)
    when :members then group_members_path(group)
    end
  end

  private
    def section_root(group)
      return GROUPLESS_HOME_ROOT if shell_section == :home && group.nil?

      SECTION_ROOTS[shell_section]
    end
end
