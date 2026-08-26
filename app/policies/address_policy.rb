class AddressPolicy < ApplicationPolicy
  # An address has no group of its own - it is reachable through whichever group or event points
  # at it, which `reachable?` already answers directly. The shared membership pre-checks ask a
  # single `group_for`, and forcing one here would mean inventing a group for a record that can
  # belong to several, so this policy answers reachability itself instead of joining them.
  skip_pre_check :verify_membership!, :verify_active_membership!

  alias_rule :edit?, :update?, to: :show?

  relation_scope do |relation|
    relation.where(id: user.groups.where.not(address_id: nil).select(:address_id))
      .or(relation.where(id: Event.where(group: user.groups).where.not(address_id: nil).select(:address_id)))
  end

  def index? = true

  def show? = reachable?

  # Disabled until #172. Reachability is what grants access to an address, and an address is
  # reachable only because a group or an event points at it - both of those references are
  # ON DELETE RESTRICT, so a destroy this rule permitted would fail at the foreign key instead.
  # The addresses that can actually be deleted are exactly the orphans nobody may reach, which
  # leaves no case for this rule to allow. #172 decides what deleting an address should mean.
  def destroy? = false

  private
    # An address has no owner of its own. It is reached through the group that has it, or through an
    # event that has it, so the question is whether the acting user belongs to either. An orphan
    # address, pointed at by no group and no event, is reachable by nobody, which is the safe answer
    # while nothing in the app can create one deliberately.
    #
    # Role is not consulted here: belonging is the whole rule until #93 lands and #172 adds the rest.
    def reachable?
      user.groups.exists?(address_id: record.id) ||
        user.groups.joins(:events).exists?(events: { address_id: record.id })
    end
end
