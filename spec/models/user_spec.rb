require 'rails_helper'

# ## Schema Information
#
# Table name: `users`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`email`**       | `string(250)`      | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_users_on_email` (_unique_):
#     * **`email`**
#
RSpec.describe User, type: :model do
  describe "(associations)" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:sign_in_tokens).dependent(:destroy) }
    it { is_expected.to have_one(:profile).class_name("UserProfile").dependent(:destroy) }
    it { is_expected.to have_many(:members).dependent(:destroy) }
    it { is_expected.to have_many(:groups).through(:members) }
  end

  describe "(validations)" do
    it { is_expected.to normalize(:email).from(" NAME@XYZ.COM\t\n").to("name@xyz.com") }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(250) }
    it { is_expected.to allow_values("Full.Name@some.crazy.domain", "username@local").for(:email) }
    it { is_expected.not_to allow_values("Full.Name.at.another.bizarre.domain", "username").for(:email) }

    describe "(uniqueness)" do
      subject { create(:user) }

      it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    end
  end

  describe "(sign-in links outstanding when the address changes)" do
    it "consumes them, because they were sent where this account no longer answers" do
      user = create(:user)
      token = SignInToken.mint(user)

      user.update!(email: "moved.on@example.com")

      expect { SignInToken.redeem!(token) }.to raise_error(SignInToken::InvalidToken)
    end

    # `email` is the only attribute this table carries today, so without this the guard on the
    # callback would be indistinguishable from no guard at all, and the first column added would
    # start invalidating live links for nothing.
    it "leaves them alone when the record is saved without the address changing" do
      user = create(:user)
      token = SignInToken.mint(user)

      user.update!(updated_at: 1.minute.from_now)

      expect(SignInToken.redeem!(token)).to eq(user)
    end
  end

  describe "(profile creation invariant)" do
    it "builds and persists a profile automatically when created" do
      user = create(:user)

      expect(user.profile).to be_a(UserProfile).and be_persisted
    end

    it "is invalid, with the error on :profile, when build_profile is stubbed out as the presence backstop" do
      user = build(:user)
      allow(user).to receive(:build_profile)

      expect(user).not_to be_valid
      expect(user.errors[:profile]).to be_present
    end
  end
end
