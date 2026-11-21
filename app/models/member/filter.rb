# WHY: one object decides what the members list shows, as `Event::Filter` does for the events list, so the list, its tab counts, its chips, the funnel and the sheet cannot disagree. Every value the reader is not offered is dropped on the way in, so a tab or a filter outside these lists reaches no query and no link.
class Member::Filter
  include ListFilter

  TAB = :status
  # WHY: `nil` is the active list because that list is the screen's own URL, with no `status`.
  TABS = { nil => "Active", "paused" => "Paused", "pending" => "Pending", "inactive" => "Inactive" }.freeze
  # WHY: who has left and who is waiting to be let in are the `MemberPolicy#oversee?` columns' reads, as the inactive toggle and the pending rows were.
  OVERSEER_TABS = %w[ pending inactive ].freeze
  ROLES = Role::NAMES.index_with(&:humanize).freeze
  MISCELLANEOUS = { "manages" => "Manages events", "not_signed_in" => "Not signed in yet" }.freeze

  # WHY: whether the reader oversees the list is the policy's answer, so the controller asks it and hands it in rather than this object reading roles.
  def self.from(member, params, oversees:)
    new(member, oversees:, status: params[:status], roles: params[:role], manages: params[:manages], not_signed_in: params[:not_signed_in])
  end

  attr_reader :member, :status, :roles

  def initialize(member, oversees: false, status: nil, roles: nil, manages: nil, not_signed_in: nil)
    @member = member
    @oversees = oversees
    @status = status.presence_in(offered_tabs.keys.compact)
    @roles = ROLES.keys & Array(roles)
    # WHY: only the "1" the sheet sends, as `Event::Filter` reads its managed flag, since a boolean cast reads any unknown string as on.
    @manages = manages.to_s == "1"
    @not_signed_in = oversees? && not_signed_in.to_s == "1"
  end

  def tab = status

  def oversees? = @oversees

  def manages? = @manages

  def not_signed_in? = @not_signed_in

  def offered_tabs = oversees? ? TABS : TABS.except(*OVERSEER_TABS)

  def apply(members) = narrow(members).where(status: status || "active")

  # WHY: every filter but the tab's own, as the events tabs count, so a tab never contradicts the rows it would list.
  def counts(members)
    narrow(members).group(:status).count.transform_keys { it unless it == "active" }
  end

  # WHY: each chip carries the parameters that leave every other filter on, so its ✕ applies what remains rather than knowing how to remove itself.
  def chips
    roles.map { [ ROLES[it], params_with(roles: roles - [ it ]) ] } +
      (manages? ? [ [ MISCELLANEOUS["manages"], params_with(manages: false) ] ] : []) +
      (not_signed_in? ? [ [ MISCELLANEOUS["not_signed_in"], params_with(not_signed_in: false) ] ] : [])
  end

  private
    # WHY: each filter reads its rows by id, so a member holding several roles is one row matching each of them.
    def narrow(members)
      members = members.where(id: Role.where(name: roles).select(:member_id)) if roles.any?
      members = members.where(id: Event.where(group_id: member.group_id).select(:manager_id)) if manages?
      members = members.where(user_id: User.where(first_signed_in_at: nil).select(:id)) if not_signed_in?
      members
    end

    def params_with(status: self.status, roles: self.roles, manages: manages?, not_signed_in: not_signed_in?)
      { status:, role: roles, manages: ("1" if manages), not_signed_in: ("1" if not_signed_in) }.compact_blank
    end
end
