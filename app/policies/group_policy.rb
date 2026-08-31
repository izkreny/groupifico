# A group is its own answer to "which group is this in".
#
# `index?` and `create?` skip the membership pre-checks: there is no group to belong to yet when
# listing groups or making a new one, so `group_for` would be asked about a record that either has
# no id (a new group) or no useful one (the `Group` class itself, for the index). Any signed-in
# user may list groups and start a new one; which groups they see is the scope's job.
#
# `new?` is absent from both lists rather than forgotten. Action Policy aliases it to `create?` and
# drops that alias the moment a real method of the name exists, so a `new?` here would let the form
# and the submission answer differently - the split `ApplicationPolicy` avoids by leaving `new?`
# out of `WRITE_RULES`. The alias resolves before anything reads `result.rule`, so `new?` arrives
# as `create?` and the skip covers it without naming it.
class GroupPolicy < ApplicationPolicy
  skip_pre_check :verify_membership!, :verify_active_membership!, only: %i[ index? create? ]

  relation_scope { |relation| relation.merge(user.current_groups) }

  def index?  = true
  def create? = true

  # The group table in docs/AUTHORIZATION.md, one rule per row. Belonging is the whole of the read
  # row, and the three write rows are the owner's alone - an administrator is refused all three,
  # which is the split `can_manage?` cannot express and `Member#owner?` exists for.
  def show? = true

  # `edit?` spells the same question out rather than reaching `update?` through an alias or a
  # `check?`, and both routes were tried. `write_rule?` matches whichever rule the running result
  # names, and both routes rename it: an alias resolves `edit?` to `update?` before the pre-checks
  # see it, and `check?` goes through `Reasons#allowed_to?`, which calls `apply_r` and pushes a
  # fresh result of its own. Either way a paused owner is refused the form they are allowed to
  # read - watched failing as `<GroupPolicy#edit?: false (reasons: {group: [:update?]})>`. Three
  # words of repetition keep the read and the write answering under their own names.
  def edit?    = membership.owner?
  def update?  = membership.owner?
  def destroy? = membership.owner?

  private
    def group_for(record) = record
end
