# == Schema Information
#
# Table name: user_profiles
#
#  id           :integer          not null, primary key
#  first_name   :string(250)
#  last_name    :string(250)
#  mobile_phone :string(50)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_user_profiles_on_mobile_phone  (mobile_phone) UNIQUE
#  index_user_profiles_on_user_id       (user_id) UNIQUE
#
# Foreign Keys
#
#  user_id  (user_id => users.id) ON DELETE => cascade ON UPDATE => cascade
#
class UserProfile < ApplicationRecord
  belongs_to :user

  validates_associated :user
  validates :user, presence: true
  validates :first_name, :last_name, length: { maximum: 250 }
  validates :mobile_phone, uniqueness: true, length: { maximum: 50 }
end
