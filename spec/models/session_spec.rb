require 'rails_helper'

RSpec.describe Session, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
  end

  describe "starting one" do
    it "records when a user who has never signed in first does" do
      user = create(:user)

      travel_to Time.zone.local(2026, 10, 1, 9, 30) do
        user.sessions.create!
      end

      expect(user.reload.first_signed_in_at).to eq Time.zone.local(2026, 10, 1, 9, 30)
    end

    it "leaves the first sign-in alone on every later one" do
      user = create(:user)
      travel_to(Time.zone.local(2026, 10, 1, 9, 30)) { user.sessions.create! }

      travel_to(Time.zone.local(2026, 10, 2, 18, 0)) { user.sessions.create! }

      expect(user.reload.first_signed_in_at).to eq Time.zone.local(2026, 10, 1, 9, 30)
    end
  end
end
