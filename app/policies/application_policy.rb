# Base class for every policy in this application.
#
# It looks empty and is not. ActionPolicy::Base sets `manage?` as the default rule and defines it
# as false, so a rule a policy does not define falls through to it and is denied rather than
# raising. Deny-by-default is inherited from here; nothing needs writing to get it.
#
# Belonging and status are asked once, here, rather than repeated per policy: every subclass that
# answers `group_for` gets both for free, so the next controller added to the app cannot quietly
# rejoin the set of unprotected ones. A subclass that has no group at all (`AddressPolicy`) skips
# both pre-checks explicitly rather than answering `group_for` with a guess.
class ApplicationPolicy < ActionPolicy::Base
  # Rules whose whole point is changing the record. `new?` counts as one of them and is absent
  # only because Action Policy already aliases it to `create?`: offering somebody a creation form
  # they will be refused at submission is worse than refusing them at the link. What is left -
  # `show?`, `edit?`, and `index?` where it reaches this far - is read, and a `paused` member
  # keeps read.
  # `manage_roles?` is here because granting or revoking a role is a write like any other, and a
  # rule absent from this list is read: a paused member would keep it while losing `update?`, which
  # is the one combination the roles rule must never allow.
  WRITE_RULES = %i[ create? update? destroy? manage_roles? ].freeze

  # `authorize!` resolves its `to:` rule against the policy *before* the pre-checks below ever run,
  # so a rule nobody defines here does not reach `verify_active_membership!` as itself - it falls
  # through Action Policy's own default chain to `manage?` first, and `write_rule?` can no longer
  # tell it apart from `show?`. These four exist to stop that fall-through. `new?`, `create?` and
  # `index?` need no such stub - Action Policy's own base class already defines `create?`/`index?`
  # and aliases `new?` to `create?`.
  #
  # They return false, and that is load-bearing rather than tidy: it is what every subclass is
  # measured against. `verify_active_membership!` refuses and never grants, so an active member
  # reaches the rule itself and one of these bodies is the answer wherever the subclass wrote none.
  # A stub returning true would hand every such subclass a granted `destroy?` nobody wrote, which
  # is how AddressPolicy once acquired one: its policy spec reported
  # `Expected to fail but succeed: <AddressPolicy#destroy?: true>` the moment its own rule was
  # removed. Deny-by-default is the whole point, so the price is that a subclass relying on the
  # pre-checks must define every rule it means to grant.
  def show?    = false
  def edit?    = false
  def update?  = false
  def destroy? = false

  pre_check :verify_membership!
  pre_check :verify_active_membership!

  private
    # Which group `record` belongs to. Every policy that relies on the pre-checks above overrides
    # this; there is no default that guesses, so a policy that forgets raises rather than quietly
    # passing every check.
    def group_for(_record)
      raise NotImplementedError, "#{self.class} must implement #group_for"
    end

    def membership
      @membership ||= Member.find_by(group: group_for(record), user: user)
    end

    # No `Member` row at all: the record does not exist for this user, so it gets `404` rather
    # than a `403` that would confirm the id exists.
    def verify_membership!
      return if membership

      details[:not_found] = true
      deny!(:not_found)
    end

    # A member belongs; whether they may currently act is a status question, not a role one.
    # `inactive` has left and is refused exactly like a non-member. `paused` still belongs and keeps
    # read, but not write.
    #
    # It refuses and never grants, which is what makes every rule below it reachable. An `allow!`
    # here would settle authorization outright and the rule would never run, so a role rule written
    # under one moves no verdict at all: every active member would already have been granted. The
    # bare `return` says "this pre-check has no objection", and the rule decides.
    def verify_active_membership!
      return if membership.active?
      return if membership.paused? && !write_rule?
      return deny! if membership.paused?

      details[:not_found] = true
      deny!(:not_found)
    end

    def write_rule?
      WRITE_RULES.include?(result.rule)
    end
end
