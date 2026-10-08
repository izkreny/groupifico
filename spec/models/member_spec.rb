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
      member = create(:member, :events_administrator)

      expect(member.can_manage?(:events)).to be true
    end

    it "answers false for a module no role of the member administers" do
      member = create(:member, :events_administrator)

      expect(member.can_manage?(:polls)).to be false
    end

    it "answers false for the members module when the member administers a different one" do
      member = create(:member, :events_administrator)

      expect(member.can_manage?(:members)).to be false
    end

    it "answers every module for a member holding owner alongside a module role" do
      member = create(:member, roles: [ build(:role, name: Role::OWNER), build(:role, name: "events_administrator") ])

      expect(member.can_manage?(:events)).to be true
      expect(member.can_manage?(:polls)).to be true
    end

    it "answers the members module for an owner holding no other role" do
      member = create(:member, :owner)

      expect(member.roles.map(&:name)).to eq [ "owner" ]
      expect(member.can_manage?(:members)).to be true
    end

    it "answers the members module for a members_administrator, and nothing else" do
      member = create(:member, :members_administrator)

      expect(member.can_manage?(:members)).to be true
      expect(member.can_manage?(:events)).to be false
    end

    it "answers nothing for a member holding no role at all" do
      member = create(:member)

      expect(member.can_manage?(:events)).to be false
      expect(member.can_manage?(:members)).to be false
    end

    it "answers a module role the vocabulary has never heard of, so a new one needs no migration" do
      member = create(:member)
      member.roles.build(name: "polls_administrator")

      expect(member.can_manage?(:polls)).to be true
    end
  end

  describe "#owner?" do
    it "answers true for a member holding the owner role" do
      member = create(:member, :owner)

      expect(member.owner?).to be true
    end

    it "answers false for an administrator, who can manage every module and owns nothing" do
      member = create(:member, :administrator)

      expect(member.can_manage?(:members)).to be true
      expect(member.owner?).to be false
    end

    it "answers false for a member holding no role at all" do
      member = create(:member)

      expect(member.owner?).to be false
    end
  end

  # A domain invariant rather than an authorization rule: it holds whoever is asking, the last owner
  # acting on themselves included, which is why no policy states it.
  describe "the last owner" do
    it "cannot be removed from the group" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, group:)

      expect(owner.destroy).to be false
      expect(described_class.exists?(owner.id)).to be true
    end

    it "cannot be stripped of the owner role" do
      group = create(:group)
      owner = create(:member, :owner, group:)

      expect { owner.roles = [] }.to raise_error ActiveRecord::RecordNotDestroyed
      expect(owner.reload).to be_owner
    end

    it "can be removed once another member owns the group too" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, :owner, group:)

      expect(owner.destroy).to be_truthy
    end

    # The guard runs before `has_many :roles, dependent: :destroy` gets to the roles, which is what
    # `prepend: true` buys: without it the member is asked whether they own the group after their
    # roles have already gone, and the answer is always no.
    it "is asked before the member's roles are destroyed" do
      group = create(:group)
      owner = create(:member, :owner, group:)

      owner.destroy

      expect(owner.reload.roles.map(&:name)).to eq [ "owner" ]
    end

    it "cannot pause themselves, which would lock the group" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, group:)

      expect(owner.update(status: :paused)).to be false
      expect(owner.reload).to be_active
    end

    it "cannot be deactivated either" do
      group = create(:group)
      owner = create(:member, :owner, group:)

      expect(owner.update(status: :inactive)).to be false
    end

    it "can step back once another active owner exists" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, :owner, group:)

      expect(owner.update(status: :paused)).to be true
    end

    # An owner who is paused is refused every write including the one that would restore them, and
    # an inactive one has left, so neither can be the owner a group is counted as having.
    it "is not replaced by a paused owner when the last active one is removed" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, :paused, :owner, group:)

      expect(owner.destroy).to be false
    end

    it "does not stop the group itself being destroyed" do
      group = create(:group)
      create(:member, :owner, group:)

      expect(group.destroy).to be_truthy
      expect(described_class.where(group_id: group.id)).to be_empty
    end
  end

  describe "#email=" do
    it "creates the user along with the membership when no account holds the address" do
      group = create(:group)

      member = described_class.create!(group:, email: "new.person@example.com")

      expect(member.user).to eq User.find_by!(email: "new.person@example.com")
    end

    it "takes the existing account when one holds the address, however it is cased" do
      user  = create(:user, email: "known.person@example.com")
      group = create(:group)

      expect { described_class.create!(group:, email: " Known.Person@Example.com ") }
        .not_to change(User, :count)

      expect(group.members.preloaded.sole.user).to eq user
    end

    it "refuses an address no account could hold, on the email field, creating nobody" do
      member = described_class.new(group: create(:group), email: "not an address")

      expect { member.save }.not_to change(User, :count)

      expect(member.errors[:email]).to eq [ "is invalid" ]
    end

    it "refuses a blank address on the email field" do
      member = described_class.new(group: create(:group), email: "")

      expect(member).not_to be_valid
      expect(member.errors[:email]).to include "can't be blank"
    end

    it "refuses an address that already belongs to a member of the group, whatever their status" do
      existing = create(:member, :inactive)

      member = described_class.new(group: existing.group, email: existing.user.email)

      expect(member).not_to be_valid
      expect(member.errors[:email]).to eq [ "already belongs to a member of this group" ]
    end

    it "accepts an address that belongs to a member of another group" do
      elsewhere = create(:member)

      member = described_class.new(group: create(:group), email: elsewhere.user.email)

      expect(member).to be_valid
    end
  end

  # #91: the unique index refuses a second membership as an exception; this is the same rule as a
  # validation, so every save meets it, not only the new member form.
  describe "one membership per user in a group" do
    it "refuses moving an existing membership onto a user the group already holds" do
      group  = create(:group)
      held   = create(:member, group:)
      member = create(:member, group:)

      member.user = held.user

      expect(member).not_to be_valid
      expect(member.errors[:email]).to eq [ "already belongs to a member of this group" ]
    end

    it "lets an existing membership save without counting itself as a duplicate" do
      member = create(:member, :active)

      expect(member.update(status: :paused)).to be true
    end
  end

  it { is_expected.to delegate_method(:full_name).to(:profile) }
  it { is_expected.to delegate_method(:short_name).to(:profile) }
  it { is_expected.to delegate_method(:initials).to(:profile) }
  it { is_expected.to delegate_method(:mobile_phone).to(:profile) }

  describe "#full_name" do
    it "answers the email local part for a fresh signup whose profile has no name yet" do
      member = create(:member, user: create(:user, email: "fresh.signup@example.com"))

      expect(member.full_name).to eq "fresh.signup"
    end
  end
end
