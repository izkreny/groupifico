module MembersHelper
  JOINED_FORMAT = "%-d %b %Y"

  # The tag a role reads as on the roster and the member screen, per the frames' legend: `owner`,
  # `admin`, `events admin`, `members admin`. Derived rather than listed, so a further module role
  # in `Role::NAMES` gets its tag with no change here.
  def role_tag(name)
    name.sub("administrator", "admin").tr("_", " ")
  end

  # Each role checkbox's name, label, hint, and the narrower names it greys once ticked, in
  # `Role::NAMES` order. The hint is derived for the same reason as the tag above, which is why the
  # members role reads "members only" where frame 3d writes "roster only".
  def role_choices
    Role::NAMES.map do |name|
      role = Role.new(name:)

      [ name, name.humanize, role_hint(name), Role::NAMES.select { role.implies?(it) } ]
    end
  end

  def member_status_choices
    Member.statuses.keys.map { [ it.capitalize, it ] }
  end

  def member_joined_on(member)
    member.created_at.strftime(JOINED_FORMAT)
  end

  private
    def role_hint(name)
      case name
      when Role::OWNER then "everything"
      when "administrator" then "all modules"
      else "#{name.delete_suffix("_administrator")} only"
      end
    end
end
