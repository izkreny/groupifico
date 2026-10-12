require 'rails_helper'

RSpec.describe Styleguides::SessionPolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:context) { { user: } }

  describe_rule :create? do
    succeed "when the member belongs to the styleguide group" do
      let(:record) { create(:member, group: create(:group, name: StyleguidesController::GROUP_NAME)) }
    end

    failed "when the member belongs to any other group" do
      let(:record) { create(:member) }
    end
  end
end
