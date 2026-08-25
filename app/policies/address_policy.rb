class AddressPolicy < ApplicationPolicy
  alias_rule :edit?, :update?, :destroy?, to: :show?

  def show? = reachable?

  private
    # An address has no owner of its own. It is reached through the group that has it, or through an
    # event that has it, so the question is whether the acting user belongs to either. An orphan
    # address, pointed at by no group and no event, is reachable by nobody, which is the safe answer
    # while nothing in the app can create one deliberately.
    #
    # Role is not consulted here: belonging is the whole rule until #93 lands and #172 adds the rest.
    # Destroying is aliased to reading for that same reason, and the alias falls away by itself the
    # moment destroy? is given a body of its own.
    def reachable?
      user.groups.exists?(address_id: record.id) ||
        user.groups.joins(:events).exists?(events: { address_id: record.id })
    end
end
