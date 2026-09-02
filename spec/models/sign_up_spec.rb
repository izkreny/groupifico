require 'rails_helper'

RSpec.describe SignUp, type: :model do
  describe "(validations)" do
    it { is_expected.to normalize(:email).from(" NAME@XYZ.COM\t\n").to("name@xyz.com") }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:group_name) }
    it { is_expected.to validate_length_of(:email).is_at_most(250) }
    it { is_expected.to validate_length_of(:group_name).is_at_most(250) }

    # The same addresses `User` accepts and refuses. An address that passed here and failed there
    # would take the link to a transaction that can never commit.
    it { is_expected.to allow_values("Full.Name@some.crazy.domain", "username@local").for(:email) }
    it { is_expected.not_to allow_values("Full.Name.at.another.bizarre.domain", "username").for(:email) }

    # No uniqueness on the address, deliberately: two rows for one address carry two group names
    # and two intents, and a uniqueness error would also make the form answer differently on an
    # address that has already asked.
    it "accepts a second outstanding request for one address" do
      create(:sign_up, email: "starter@example.com")

      expect(build(:sign_up, email: "starter@example.com")).to be_valid
    end
  end

  describe ".redeem!" do
    it "returns the owner membership of the group it created" do
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")

      member = described_class.redeem!(token)

      expect(member.user.email).to eq("starter@example.com")
      expect(member.group.name).to eq("Chamber Choir")
      expect(member).to be_owner
    end

    it "adds the group to an account already holding the address, never a second account" do
      user = create(:user, email: "starter@example.com")
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")

      expect { described_class.redeem!(token) }.not_to change(User, :count)

      expect(user.current_groups.map(&:name)).to include("Chamber Choir")
    end

    it "signs in on the last second of the window" do
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")

      travel_to described_class::EXPIRES_IN.from_now do
        expect(described_class.redeem!(token).group.name).to eq("Chamber Choir")
      end
    end

    it "refuses one second past the window" do
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")

      travel_to described_class::EXPIRES_IN.from_now + 1.second do
        expect { described_class.redeem!(token) }.to raise_error(described_class::InvalidToken)
      end
    end

    it "refuses a second use of one link" do
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")
      described_class.redeem!(token)

      expect { described_class.redeem!(token) }.to raise_error(described_class::InvalidToken)
    end

    it "raises the typed error for a blank token" do
      expect { described_class.redeem!(nil) }.to raise_error(described_class::InvalidToken)
      expect { described_class.redeem!("") }.to raise_error(described_class::InvalidToken)
    end

    # There is a session from here on, so an outstanding sign-in link sent to this address signs
    # in whoever holds it. `SignInToken.redeem!` consumes them for the same reason.
    it "consumes the account's outstanding sign-in links" do
      spare = SignInToken.mint(create(:user, email: "starter@example.com"))
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")

      described_class.redeem!(token)

      expect { SignInToken.redeem!(spare) }.to raise_error(SignInToken::InvalidToken)
    end

    # Two requests for one address are two different intents. Consuming the second here would
    # silently discard a group this person also asked for.
    it "leaves the address's other outstanding requests alone" do
      first  = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")
      second = described_class.mint(email: "starter@example.com", group_name: "Brass Band")

      described_class.redeem!(first)

      expect(described_class.redeem!(second).group.name).to eq("Brass Band")
    end

    # The spend is inside the transaction, so a failure anywhere rolls it back and the link stays
    # live for a retry rather than being burnt. Staged with `update_columns`, which is the only
    # way past the model's own validations to a row the transaction has to refuse: SQLite does not
    # enforce the column's length, so a blank group name reaches `Group` and is refused there. The
    # row is reached by its address rather than by `.sole`, so any other writer of this table fails
    # the assertion this example makes instead of masking it behind `SoleRecordExceeded`.
    #
    # Watched failing against a version that spends before `transaction do` opens: the link came
    # back consumed and the person holding it had nothing left to retry with.
    it "creates nothing and leaves the link live when any part fails" do
      token = described_class.mint(email: "starter@example.com", group_name: "Chamber Choir")
      described_class.find_by!(email: "starter@example.com").update_columns(group_name: "")

      expect { described_class.redeem!(token) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(described_class.find_by!(email: "starter@example.com").consumed_at).to be_nil
      expect(User.where(email: "starter@example.com")).not_to exist
      expect(Group.where(name: "")).not_to exist
    end
  end
end
