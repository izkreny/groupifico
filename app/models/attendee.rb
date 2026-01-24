# ## Schema Information
#
# Table name: `attendees`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`event_id`**    | `integer`          | `not null`
# **`member_id`**   | `integer`          | `not null`
#
# ### Indexes
#
# * `index_attendees_on_event_id`:
#     * **`event_id`**
# * `index_attendees_on_member_id`:
#     * **`member_id`**
# * `index_attendees_on_member_id_and_event_id` (_unique_):
#     * **`member_id`**
#     * **`event_id`**
#
# ### Foreign Keys
#
# * `event_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`event_id => events.id`**
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
#
class Attendee < ApplicationRecord
  belongs_to :member
  belongs_to :event

  enum :status, %i[ reserved invited yes maybe no ], default: :reserved, validate: true
end
