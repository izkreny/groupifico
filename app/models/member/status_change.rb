# ## Schema Information
#
# Table name: `member_status_changes`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`starts_on`**   | `date`             | `not null`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`member_id`**   | `integer`          | `not null`
# **`updater_id`**  | `integer`          |
#
# ### Indexes
#
# * `index_member_status_changes_on_member_id_and_starts_on` (_unique_):
#     * **`member_id`**
#     * **`starts_on`**
# * `index_member_status_changes_on_updater_id`:
#     * **`updater_id`**
#
# ### Foreign Keys
#
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
# * `updater_id` (_ON DELETE => nullify ON UPDATE => cascade_):
#     * **`updater_id => members.id`**
#

# One change of a member's status: from `starts_on` on, the member's status is `status`. A period is never stored; it runs from one change to the day before the next, per ADR 0008.
class Member::StatusChange < ApplicationRecord
  belongs_to :member
  # WHY: required on every write, because every write sets it, while the column stays nullable so the foreign key can clear it when its member is deleted and the change survives with no author.
  belongs_to :updater, class_name: "Member"

  enum :status, Member.statuses, validate: true

  # WHY: `state_machines-audit_trail` writes the new state through `to=` and each context value through a writer named after the `Member` attribute it reads, while the columns are named for what they hold.
  alias_attribute :to, :status
  alias_attribute :status_starts_on, :starts_on
  alias_method :status_updater=, :updater=
end
