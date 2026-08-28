require 'rails_helper'

# ## Schema Information
#
# Table name: `members`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`group_id`**    | `integer`          | `not null`
# **`user_id`**     | `integer`          | `not null`
#
# ### Indexes
#
# * `index_members_on_group_id`:
#     * **`group_id`**
# * `index_members_on_user_id`:
#     * **`user_id`**
# * `index_members_on_user_id_and_group_id` (_unique_):
#     * **`user_id`**
#     * **`group_id`**
#
# ### Foreign Keys
#
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
RSpec.describe Member, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to have_one(:profile).through(:user) }
    it { is_expected.to have_many(:registrations).dependent(:destroy) }
    it { is_expected.to have_many(:roles).dependent(:destroy) }
    it { is_expected.to have_many(:events).through(:registrations) }
    it { is_expected.to have_many(:created_events).class_name("Event").with_foreign_key("creator_id").inverse_of(:creator) }
    it { is_expected.to have_many(:managed_events).class_name("Event").with_foreign_key("manager_id").inverse_of(:manager) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, paused: 1, inactive: 2).with_default(:active).validating }
  end

  describe "#can_manage?" do
    it "answers true for the module a single module role administers" do
      member = create(:member, roles: [ build(:role, name: "events_administrator") ])

      expect(member.can_manage?(:events)).to be true
    end

    it "answers false for a module no role of the member administers" do
      member = create(:member, roles: [ build(:role, name: "events_administrator") ])

      expect(member.can_manage?(:songs)).to be false
    end

    it "answers false for a module with no role of its own when the member is not an administrator" do
      member = create(:member, roles: [ build(:role, name: "events_administrator") ])

      expect(member.can_manage?(:members)).to be false
    end

    it "answers both modules for a member holding two module roles at once" do
      member = create(:member, roles: [ build(:role, name: "events_administrator"), build(:role, name: "songs_administrator") ])

      expect(member.can_manage?(:events)).to be true
      expect(member.can_manage?(:songs)).to be true
    end

    it "answers an administrator-only question for an owner holding no administrator role" do
      member = create(:member, roles: [ build(:role, name: "owner") ])

      expect(member.roles.map(&:name)).to eq [ "owner" ]
      expect(member.can_manage?(:members)).to be true
    end

    it "answers nothing for a member holding no role at all" do
      member = create(:member)

      expect(member.can_manage?(:events)).to be false
      expect(member.can_manage?(:members)).to be false
    end

    it "answers a module role added to the vocabulary without a migration" do
      stub_const("Role::NAMES", Role::NAMES + [ "polls_administrator" ])
      member = create(:member, roles: [ build(:role, name: "polls_administrator") ])

      expect(member.can_manage?(:polls)).to be true
    end
  end

  it { is_expected.to delegate_method(:full_name).to(:profile) }

  describe "#full_name" do
    it "answers the email local part for a fresh signup whose profile has no name yet" do
      member = create(:member, user: create(:user, email: "fresh.signup@example.com"))

      expect(member.full_name).to eq "fresh.signup"
    end
  end
end
