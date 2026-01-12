# == Schema Information
#
# Table name: attendees
#
#  id         :integer          not null, primary key
#  status     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null
#  member_id  :integer          not null
#
# Indexes
#
#  index_attendees_on_event_id                (event_id)
#  index_attendees_on_member_id               (member_id)
#  index_attendees_on_member_id_and_event_id  (member_id,event_id) UNIQUE
#
# Foreign Keys
#
#  event_id   (event_id => events.id) ON DELETE => cascade ON UPDATE => cascade
#  member_id  (member_id => members.id) ON DELETE => cascade ON UPDATE => cascade
#
class Attendee < ApplicationRecord
  belongs_to :member
  belongs_to :event

  enum :status, %i[ reserved invited yes maybe no ], default: :reserved
end
