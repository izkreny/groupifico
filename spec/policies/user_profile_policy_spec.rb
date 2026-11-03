require 'rails_helper'

RSpec.describe UserProfilePolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { user.profile }
  let(:context) { { user: user } }

  describe_rule :edit? do
    succeed "when the profile belongs to the user"

    failed "when the profile belongs to someone else" do
      let(:record) { create(:user).profile }
    end
  end

  # A declared alias rather than a rule that repeats edit?. Action Policy drops an alias the moment a
  # real method of that name is defined, so the day update? grows its own body this example fails
  # and forces it a describe_rule of its own.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(:update?).to be_an_alias_of(policy, :edit?) }
  end
end
