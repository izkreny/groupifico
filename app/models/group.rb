# == Schema Information
#
# Table name: groups
#
#  id          :integer          not null, primary key
#  description :text(100000)
#  group_type  :integer          not null
#  name        :string(250)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  address_id  :integer
#
# Foreign Keys
#
#  address_id  (address_id => addresses.id) ON DELETE => restrict ON UPDATE => cascade
#
class Group < ApplicationRecord
  belongs_to :address, optional: true, touch: true
  has_many :members, dependent: :destroy
  has_many :events, dependent: :destroy

  enum :group_type, %i[ group choir band ], default: :choir
end
