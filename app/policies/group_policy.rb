# A group is its own answer to "which group is this in".
#
# `index?`, `new?` and `create?` skip the membership pre-checks: there is no group to belong to
# yet when listing groups or making a new one, so `group_for` would be asked about a record that
# either has no id (a new group) or no useful one (the `Group` class itself, for the index). Any
# signed-in user may list groups and start a new one; which groups they see is the scope's job.
class GroupPolicy < ApplicationPolicy
  skip_pre_check :verify_membership!, :verify_active_membership!, only: %i[ index? new? create? ]

  relation_scope { |relation| relation.merge(user.groups) }

  def index?  = true
  def new?    = true
  def create? = true

  private
    def group_for(record) = record
end
