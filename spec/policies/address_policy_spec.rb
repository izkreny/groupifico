require 'rails_helper'

RSpec.describe AddressPolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { create(:address) }
  let(:context) { { user: user } }

  describe_rule :show? do
    failed "when no group or event of the user's points at the address"

    succeed "when a group the user belongs to has the address" do
      before { create(:member, user: user, group: create(:group, address: record)) }
    end

    succeed "when an event of a group the user belongs to has the address" do
      before do
        member = create(:member, user: user)
        create(:event, group: member.group, address: record)
      end
    end

    failed "when the group holding the address is one the user does not belong to" do
      before { create(:group, address: record) }
    end
  end

  describe_rule :destroy? do
    failed "when no group or event of the user's points at the address"

    # The case worth having. Reaching the address is what show? grants, and destroy? deliberately
    # does not follow it: the group below holds an ON DELETE RESTRICT reference, so allowing this
    # would replace a refusal with a foreign key violation. Denied until #172.
    failed "when a group the user belongs to has the address" do
      before { create(:member, user: user, group: create(:group, address: record)) }
    end
  end

  # Declared aliases rather than rules that repeat show?. Action Policy drops an alias the moment a
  # real method of that name is defined, which is how destroy? leaving this list was caught rather
  # than noticed: its example here failed the moment the rule grew a body of its own.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(:edit?).to be_an_alias_of(policy, :show?) }
    it { expect(:update?).to be_an_alias_of(policy, :show?) }
  end
end
