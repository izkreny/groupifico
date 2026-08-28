require 'rails_helper'

# ## Schema Information
#
# Table name: `roles`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`name`**        | `string`           | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`member_id`**   | `integer`          | `not null`
#
# ### Indexes
#
# * `index_roles_on_member_id`:
#     * **`member_id`**
# * `index_roles_on_member_id_and_name` (_unique_):
#     * **`member_id`**
#     * **`name`**
#
# ### Foreign Keys
#
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
#
RSpec.describe Role, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
  end

  describe "(validations)" do
    subject { build(:role) }

    it { is_expected.to validate_inclusion_of(:name).in_array(Role::NAMES) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:member_id) }
  end

  describe "#grants?" do
    it "answers true for the module its own name administers" do
      role = build(:role, name: "events_administrator")

      expect(role.grants?(:events)).to be true
    end

    it "answers false for a module another role administers" do
      role = build(:role, name: "events_administrator")

      expect(role.grants?(:songs)).to be false
    end

    it "answers true for every module when the role is administrator" do
      role = build(:role, name: "administrator")

      expect(role.grants?(:songs)).to be true
    end

    it "answers true for every module when the role is owner" do
      role = build(:role, name: "owner")

      expect(role.grants?(:songs)).to be true
    end
  end
end
