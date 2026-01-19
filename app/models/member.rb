# == Schema Information
#
# Table name: members
#
#  id         :integer          not null, primary key
#  role       :integer          not null
#  status     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_members_on_group_id              (group_id)
#  index_members_on_user_id               (user_id)
#  index_members_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
# Foreign Keys
#
#  group_id  (group_id => groups.id) ON DELETE => cascade ON UPDATE => cascade
#  user_id   (user_id => users.id) ON DELETE => cascade ON UPDATE => cascade
#
class Member < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_one :profile, through: :user
  has_many :attendees, dependent: :destroy
  has_many :events, through: :attendees
  has_many :created_events, class_name: "Event", foreign_key: "creator_id", inverse_of: :creator
  has_many :managed_events, class_name: "Event", foreign_key: "manager_id", inverse_of: :manager

  enum :status, %i[ active paused inactive ], default: :active, validate: true
  enum :role, %i[ owner member admin manager ], default: :member, validate: true

  validates_associated :user, :group
  validates :user, :group, presence: true
end
