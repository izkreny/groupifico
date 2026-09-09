module ApplicationHelper
  # Which of the shell's three tabs is current. Derived from the controller rather than declared by
  # each of them, because a declaration would put #244's diff into eight controllers that own their
  # own screens, and because the mapping is the whole of what "the section's tab is marked for its
  # whole stack" means: an event, its roster and the events list all answer `:events`.
  SHELL_SECTIONS = {
    "groups" => :home, "events" => :events, "registrations" => :events, "members" => :members
  }.freeze

  # Actions that render a form. `create` and `update` are here beside the three that only ever show
  # one because both re-render their form on a failed save, so a list of the GET actions alone
  # would draw tabs on exactly the screens a reader reaches by getting a form wrong.
  FORM_ACTIONS = %w[ new create edit update duplicate ].freeze

  def shell_section
    SHELL_SECTIONS[controller_name]
  end

  # Takes the group rather than reading `@group`, so the layout stays the one place in the shell
  # that touches a controller instance variable. A `nil` group covers both screens outside a group
  # and `groups#index`, which maps to `:home` above and has no group of its own.
  def shell_tabs?(group)
    group.present? && shell_section.present? && FORM_ACTIONS.exclude?(action_name)
  end
end
