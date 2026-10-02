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

  describe ".answer?" do
    # Written out rather than read from `Registration::ANSWERS`, for the reason the sibling below
    # gives: an example iterating the constant agrees with whatever it holds.
    it "answers true for each of the three answers, and for a blank" do
      expect(described_class.answer?("yes")).to be true
      expect(described_class.answer?("maybe")).to be true
      expect(described_class.answer?("no")).to be true
      expect(described_class.answer?(nil)).to be true
    end

    it "answers false for the two statuses somebody else writes" do
      expect(described_class.answer?("reserved")).to be false
      expect(described_class.answer?("invited")).to be false
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

  describe "#invite" do
    it "moves a reserved registration to invited" do
      registration = create(:registration, status: :reserved)

      expect(registration.invite).to be true
      expect(registration.reload).to be_invited
    end

    it "leaves an invited or answered registration as it was" do
      invited = create(:registration, status: :invited)
      answered = create(:registration, event: create(:event, status: :confirmed), status: :yes)

      expect([ invited.invite, answered.invite ]).to eq [ false, false ]
      expect([ invited.reload.status, answered.reload.status ]).to eq %w[ invited yes ]
    end

    it "leaves a paused or inactive member's held place reserved" do
      paused = create(:registration, member: create(:member, :paused), status: :reserved)
      gone = create(:registration, member: create(:member, :inactive), status: :reserved)

      expect([ paused.invite, gone.invite ]).to eq [ false, false ]
      expect([ paused.reload.status, gone.reload.status ]).to eq %w[ reserved reserved ]
    end
  end
end
