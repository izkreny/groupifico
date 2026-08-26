class AddressPolicy < ApplicationPolicy
  alias_rule :edit?, :update?, to: :show?

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
