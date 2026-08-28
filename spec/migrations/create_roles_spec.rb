require 'rails_helper'
require Rails.root.join("db/migrate/20260828093000_create_roles.rb")

# The backfill runs against the column it exists to drain, so the example puts that column back for
# its own duration and inserts a row per legacy enum value.
RSpec.describe CreateRoles do
  it "leaves every member with the capabilities their enum value carried" do
    group = create(:group)
    connection = described_class.new.connection
    connection.add_column :members, :role, :integer
    Member.reset_column_information

    members = { owner: 0, member: 1, admin: 2, manager: 3 }.transform_values do |value|
      create(:member, group: group).tap { connection.execute("UPDATE members SET role = #{value} WHERE id = #{it.id}") }
    end

    described_class.new.backfill_roles

    expect(members[:owner].can_manage?(:members)).to be true
    expect(members[:owner].can_manage?(:events)).to be true
    expect(members[:admin].can_manage?(:members)).to be true
    expect(members[:manager].can_manage?(:events)).to be true
    expect(members[:manager].can_manage?(:members)).to be false
    expect(members[:member].roles).to be_empty
  ensure
    connection.remove_column :members, :role
    Member.reset_column_information
  end
end
