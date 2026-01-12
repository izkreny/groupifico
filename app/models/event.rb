# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  description :text(100000)
#  end         :datetime         not null
#  event_type  :integer          not null
#  name        :string(250)      not null
#  start       :datetime         not null
#  status      :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  address_id  :integer
#  creator_id  :bigint           not null
#  group_id    :integer          not null
#  manager_id  :bigint
#
# Indexes
#
#  index_events_on_group_id  (group_id)
#
# Foreign Keys
#
#  address_id  (address_id => addresses.id) ON DELETE => restrict ON UPDATE => cascade
#  group_id    (group_id => groups.id) ON DELETE => cascade ON UPDATE => cascade
#
class Event < ApplicationRecord
  belongs_to :group
  belongs_to :address, optional: true, touch: true
  belongs_to :creator, class_name: "Member", foreign_key: "creator_id", inverse_of: :created_events
  belongs_to :manager, class_name: "Member", foreign_key: "manager_id", inverse_of: :managed_events, optional: true
  has_many :attendees, dependent: :destroy
  has_many :members, through: :attendees

  enum :status, %i[ unconfirmed confirmed concluded canceled ], default: :unconfirmed
  enum :event_type, %i[ other rehearsal gig ], default: :rehearsal
end
