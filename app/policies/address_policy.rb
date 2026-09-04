# An address never lives on its own. It is always a detail of whichever record points at it - a
# group's home venue, an event's location - and the schema says so from the pointing side only:
# `groups.address_id` and `events.address_id` exist, while `Address` has no association back.
#
# So "may I touch this address" is not a question of its own. It is the same question asked of the
# records that own it, and the answer is inherited: read an address you may read the owner of,
# change one you may change the owner of. That is why this policy skips the membership pre-checks
# rather than answering `group_for` - it has no group of its own to name, and does not need one,
# because `GroupPolicy` and `EventPolicy` already carry every rule that applies.
#
# The inheritance is what makes the status split free: a `paused` member is refused `update?` on a
# group by the pre-checks, so they are refused it on that group's address without this file saying
# anything about membership at all. A new kind of owner arrives the same way - add it to `owners`
# and its own policy decides.
class AddressPolicy < ApplicationPolicy
  skip_pre_check :verify_membership!, :verify_active_membership!

  alias_rule :edit?, to: :show?

  relation_scope do |relation|
    relation.where(id: user.current_groups.where.not(address_id: nil).select(:address_id))
      .or(relation.where(id: Event.where(group: user.current_groups).where.not(address_id: nil).select(:address_id)))
  end

  def index? = true

  def show? = owners.any? { |owner| allowed_to?(:show?, owner) }

  # Not aliased to show?: `write_rule?` matches the rule that actually runs, so an aliased update?
  # arrives as show? and the read/write split never sees it. `edit?` stays aliased, because opening
  # a form is a read - a paused member is stopped at submission, the same place `duplicate` stops
  # them.
  #
  # A group's home address answers to that group alone. An event may point at it - `Group#addresses`
  # offers every address the group reaches, its own among them - but pointing at an address is using
  # it, never owning it, and `docs/AUTHORIZATION.md` reserves correcting the home address to the
  # `owner`. Asking every owner would hand it to whoever may edit the event instead, so where a group
  # holds this address the events fall away and only its policy is asked.
  #
  # `owners` is left whole because `show?` reads it too and is not affected: every owner of an
  # address belongs to one group, and belonging is the whole of the read.
  def update?
    home_of = Group.where(address_id: record.id)
    return home_of.any? { |group| allowed_to?(:update?, group) } if home_of.exists?

    owners.any? { |owner| allowed_to?(:update?, owner) }
  end

  private
    # Every record pointing at this address. `any?` rather than `all?`: rights on one owner are
    # enough, which is the only sensible reading while nothing in the application can point two
    # groups at one address. Nothing can: `EventsController#foreign_address?` drops an `address_id`
    # the acting group does not own, and the one nested-attributes door left, `GroupsController`,
    # meets Rails itself, which answers a foreign `id` there with `RecordNotFound`. Settled on #187,
    # which carries that evidence and the migration it priced out.
    #
    # An orphan has no owners, so `any?` answers false and the address is refused to everybody -
    # which is the same conclusion the old reachability rule reached, by a shorter route.
    def owners
      Group.where(address_id: record.id) + Event.where(address_id: record.id)
    end
end
