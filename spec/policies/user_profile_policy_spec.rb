require 'rails_helper'

RSpec.describe UserProfilePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:record) { user.profile }
  let(:context) { { user: user } }

  describe_rule :show? do
    succeed "when the profile belongs to the user"

    failed "when the profile belongs to someone else" do
      let(:record) { create(:user).profile }
    end
  end
end
