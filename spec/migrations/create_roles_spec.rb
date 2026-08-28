require 'rails_helper'
require Rails.root.join("db/migrate/20260828093000_create_roles.rb")

# TODO: remove this file together with db/migrate/20260828093000_create_roles.rb, whenever old
# migrations are squashed away. It has nothing left to guard once that migration is gone.
#
# The backfill runs against the column it exists to drain, so these examples put that column back
# for their own duration and insert a member carrying one legacy enum value each.
RSpec.describe CreateRoles do
  let(:connection) { described_class.new.connection }

  around do |example|
    connection.add_column :members, :role, :integer
    Member.reset_column_information
    example.run
  ensure
    connection.remove_column :members, :role
    Member.reset_column_information
  end

  describe "#backfill_roles" do
    it "leaves a member who was an owner holding the owner role" do
      member = create(:member)
      connection.execute("UPDATE members SET role = 0 WHERE id = #{member.id}")

      described_class.new.backfill_roles

      expect(member.roles.map(&:name)).to eq [ "owner" ]
      expect(member.can_manage?(:members)).to be true
    end

    it "leaves a member who was an admin holding the administrator role" do
      member = create(:member)
      connection.execute("UPDATE members SET role = 2 WHERE id = #{member.id}")

      described_class.new.backfill_roles

      expect(member.roles.map(&:name)).to eq [ "administrator" ]
      expect(member.can_manage?(:members)).to be true
    end

    it "leaves a member who was a manager administering events and nothing wider" do
      member = create(:member)
      connection.execute("UPDATE members SET role = 3 WHERE id = #{member.id}")

      described_class.new.backfill_roles

      expect(member.can_manage?(:events)).to be true
      expect(member.can_manage?(:members)).to be false
    end

    it "leaves a member who was a plain member holding no role at all" do
      member = create(:member)
      connection.execute("UPDATE members SET role = 1 WHERE id = #{member.id}")

      described_class.new.backfill_roles

      expect(member.roles).to be_empty
    end
  end
end
