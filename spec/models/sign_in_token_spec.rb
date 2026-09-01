require 'rails_helper'

RSpec.describe SignInToken, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
  end

  describe ".mint" do
    it "keeps no copy of the token it returns" do
      token = described_class.mint(create(:user))

      expect(described_class.sole.attributes.values.map(&:to_s)).not_to include(token)
    end

    it "carries at least 128 bits of entropy" do
      token = described_class.mint(create(:user))

      expect(Base64.urlsafe_decode64(token).bytesize * 8).to be >= 128
    end

    # Randomness is a boundary, which `.agents/testing.md` allows a double for, and this is the
    # assertion #139 asks for so that a later refactor to `rand` fails the suite rather than
    # passing it: an unpredictable value looks identical to a predictable one from the outside.
    it "draws the token from SecureRandom" do
      allow(SecureRandom).to receive(:urlsafe_base64).and_call_original

      described_class.mint(create(:user))

      expect(SecureRandom).to have_received(:urlsafe_base64)
    end
  end

  describe ".redeem!" do
    it "returns the user the token was minted for, and not another" do
      minted_for = create(:user)
      described_class.mint(create(:user))
      token = described_class.mint(minted_for)

      expect(described_class.redeem!(token)).to eq(minted_for)
    end

    it "signs in on the last second of the window" do
      user = create(:user)
      token = described_class.mint(user)

      travel_to described_class::EXPIRES_IN.from_now do
        expect(described_class.redeem!(token)).to eq(user)
      end
    end

    it "refuses one second past the window" do
      token = described_class.mint(create(:user))

      travel_to described_class::EXPIRES_IN.from_now + 1.second do
        expect { described_class.redeem!(token) }.to raise_error(described_class::InvalidToken)
      end
    end

    it "refuses a second use of one link" do
      token = described_class.mint(create(:user))
      described_class.redeem!(token)

      expect { described_class.redeem!(token) }.to raise_error(described_class::InvalidToken)
    end

    it "consumes the account's other outstanding links" do
      user = create(:user)
      spare = described_class.mint(user)

      described_class.redeem!(described_class.mint(user))

      expect { described_class.redeem!(spare) }.to raise_error(described_class::InvalidToken)
    end

    it "raises the typed error for a blank token" do
      expect { described_class.redeem!(nil) }.to raise_error(described_class::InvalidToken)
      expect { described_class.redeem!("") }.to raise_error(described_class::InvalidToken)
    end

    # The digest call raises `TypeError` on anything that is not a string, which would reach a
    # controller's `rescue InvalidToken` as a 500 rather than as a refusal.
    it "raises the typed error for a token that is not a string" do
      expect { described_class.redeem!([ "not-a-token" ]) }.to raise_error(described_class::InvalidToken)
    end

    # The mechanism assertion #139 asks for on the comparison side. Reading the row, comparing in
    # Ruby and then updating it by id is a time-of-check gap that two concurrent redemptions both
    # pass, and it is invisible in every other example here because it passes them all. The
    # statement order is the point, so reading the first captured statement is deliberate.
    it "spends the token in one conditional write, with no read before it to race against" do
      token = described_class.mint(create(:user))
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        statements << payload[:sql] if payload[:sql].include?("sign_in_tokens")
      end

      described_class.redeem!(token)
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(statements.first).to start_with("UPDATE")
    end
  end

  describe ".consume_all" do
    it "leaves an already consumed link's timestamp alone" do
      user = create(:user)
      token = described_class.mint(user)
      described_class.redeem!(token)
      consumed_at = described_class.sole.consumed_at

      travel_to 1.hour.from_now do
        user.sign_in_tokens.consume_all
      end

      expect(described_class.sole.consumed_at).to eq(consumed_at)
    end
  end
end
