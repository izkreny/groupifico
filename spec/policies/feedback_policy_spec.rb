require "rails_helper"

RSpec.describe FeedbackPolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { build(:feedback, user:) }
  let(:context) { { user: } }

  describe_rule :create? do
    succeed "for any signed-in user, member of a group or not"
  end

  describe_rule :show? do
    succeed "when the feedback is the user's own"

    failed "when the feedback is someone else's" do
      let(:record) { build(:feedback) }
    end
  end
end
