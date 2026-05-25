require 'rails_helper'

RSpec.describe Member, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to have_one(:profile).through(:user) }
    it { is_expected.to have_many(:registrations).dependent(:destroy) }
    it { is_expected.to have_many(:events).through(:registrations) }
    it { is_expected.to have_many(:created_events).class_name("Event").with_foreign_key("creator_id").inverse_of(:creator) }
    it { is_expected.to have_many(:managed_events).class_name("Event").with_foreign_key("manager_id").inverse_of(:manager) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, paused: 1, inactive: 2).with_default(:active).validating }
    it { is_expected.to define_enum_for(:role).with_values(owner: 0, member: 1, admin: 2, manager: 3).with_default(:member).validating }
  end

  it { is_expected.to delegate_method(:full_name).to(:profile) }
end
