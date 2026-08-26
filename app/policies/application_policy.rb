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
  # Rules whose whole point is changing the record. Everything else - `show?`, `edit?`, `new?`,
  # `index?` where it reaches this far - is read, and a `paused` member keeps read.
  WRITE_RULES = %i[ create? update? destroy? ].freeze

  # `authorize!` resolves its `to:` rule against the policy *before* the pre-checks below ever run,
  # so a rule nobody defines here does not reach `verify_active_membership!` as itself - it falls
  # through Action Policy's own default chain to `manage?` first, and `write_rule?` can no longer
  # tell it apart from `show?`. These four exist to stop that fall-through. `new?`, `create?` and
  # `index?` need no such stub - Action Policy's own base class already defines `create?`/`index?`
  # and aliases `new?` to `create?`.
  #
  # They return false, and that is load-bearing rather than tidy. For a policy that keeps the
  # pre-checks the body is unreachable - allow!/deny! settles the rule first - but AddressPolicy
  # and UserProfilePolicy both `skip_pre_check` and answer reachability themselves, so for those
  # two the body is the whole rule. Returning true here handed every skipping policy a granted
  # `destroy?` it never wrote: caught when AddressPolicy's own `destroy?` was removed and its
  # policy spec reported `Expected to fail but succeed: <AddressPolicy#destroy?: true>`.
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
    # `inactive` has left and is refused exactly like a stranger. `paused` still belongs and keeps
    # read, but not write, until #93 and #96 give write its own rule to consult.
    def verify_active_membership!
      return allow! if membership.active?
      return allow! if membership.paused? && !write_rule?
      return deny! if membership.paused?

      details[:not_found] = true
      deny!(:not_found)
    end

    def write_rule?
      WRITE_RULES.include?(result.rule)
    end
end
