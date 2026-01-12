# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  email      :string(250)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :groups, through: :members
end
