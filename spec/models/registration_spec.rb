require 'rails_helper'

RSpec.describe Registration, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:event) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(reserved: 0, invited: 1, yes: 2, maybe: 3, no: 4).with_default(:reserved).validating }
  end

  # The invariant that closes the write the screen's own guard could only hide. It is on the model
  # rather than in `RegistrationPolicy` for the reason `docs/AUTHORIZATION.md` gives for the
  # last-active-owner guard: the tables decide who may act, and "this event is over" says nothing
  # about the actor.
  describe "(answering an event that is over)" do
    it "refuses an answer to an event somebody has concluded" do
      registration = create(:registration, status: :invited, event: create(:event, status: :concluded))

      expect(registration.update(status: :yes)).to be false
      expect(registration.errors[:status]).to include "cannot be answered once the event is over"
    end

    it "refuses an answer to an event that has been called off" do
      registration = create(:registration, status: :invited, event: create(:event, status: :canceled))

      expect(registration.update(status: :yes)).to be false
    end

    # The case the owner asked for: an event that has ended and that nobody concluded still takes
    # an answer, because the roster is what it is for.
    it "allows an answer to an event that has merely ended" do
      event = create(:event, status: :confirmed, starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
      registration = create(:registration, status: :invited, event:)

      expect(registration.update(status: :yes)).to be true
    end

    # `reserved` and `invited` are what somebody filling the event writes, and correcting a roster
    # after the fact is theirs rather than this rule's.
    it "leaves the filling statuses alone on a concluded event" do
      registration = create(:registration, status: :reserved, event: create(:event, status: :concluded))

      expect(registration.update(status: :invited)).to be true
    end
  end

  describe "#answered?" do
    # The three statuses are written out rather than read from `Registration::ANSWERS`, which is
    # the constant the method asks: an example iterating it agrees with whatever it holds.
    it "answers true for each of the three answers" do
      expect(build(:registration, status: :yes)).to be_answered
      expect(build(:registration, status: :maybe)).to be_answered
      expect(build(:registration, status: :no)).to be_answered
    end

    it "answers false while the registration is reserved or invited" do
      expect(build(:registration, status: :reserved)).not_to be_answered
      expect(build(:registration, status: :invited)).not_to be_answered
    end
  end
end
