require 'rails_helper'

RSpec.describe UserProfilePolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { user.profile }
  let(:context) { { user: user } }

  describe_rule :show? do
    succeed "when the profile belongs to the user"

    failed "when the profile belongs to someone else" do
      let(:record) { create(:user).profile }
    end
  end

  # Declared aliases rather than rules that repeat show?. Action Policy drops an alias the moment a
  # real method of that name is defined, so the day edit? or update? grows its own body these
  # examples fail and force it a describe_rule of its own.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(policy.resolve_rule(:edit?)).to eq :show? }
    it { expect(policy.resolve_rule(:update?)).to eq :show? }
  end
end
