require 'rails_helper'

RSpec.describe Registration, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:event) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(reserved: 0, response_requested: 1, yes: 2, maybe: 3, no: 4).with_default(:reserved).validating }
  end

  # The invariant that closes the write the screen's own guard could only hide. It is on the model
  # rather than in `RegistrationPolicy` for the reason `docs/AUTHORIZATION.md` gives for the
  # last-active-owner guard: the tables decide who may act, and "this event is concluded" says nothing
  # about the actor.
  describe "(answering a concluded or canceled event)" do
    it "refuses an answer to an event somebody has concluded" do
      registration = create(:registration, status: :response_requested, event: create(:event, status: :concluded))

      expect(registration.update(status: :yes)).to be false
      expect(registration.errors[:base]).to include "This event is concluded or canceled, so it no longer takes replies."
    end

    it "refuses an answer to an event that has been called off" do
      registration = create(:registration, status: :response_requested, event: create(:event, status: :canceled))

      expect(registration.update(status: :yes)).to be false
    end

    # The case the owner wanted: an event that has ended and that nobody concluded still takes
    # an answer, because the roster is what it is for.
    it "allows an answer to an event that has merely ended" do
      event = create(:event, status: :confirmed, starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
      registration = create(:registration, status: :response_requested, event:)

      expect(registration.update(status: :yes)).to be true
    end

    # `reserved` and `response_requested` are what somebody filling the event writes, and correcting a roster
    # after the fact is theirs rather than this rule's.
    it "leaves the filling statuses alone on a concluded event" do
      registration = create(:registration, status: :reserved, event: create(:event, status: :concluded))

      expect(registration.update(status: :response_requested)).to be true
    end
  end

  # After the end, whether somebody went is a yes or a no, so `maybe` is the one answer an ended event no longer takes.
  describe "(answering maybe after the event)" do
    it "refuses maybe to an event that has ended" do
      event = create(:event, status: :confirmed, starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
      registration = create(:registration, status: :response_requested, event:)

      expect(registration.update(status: :maybe)).to be false
      expect(registration.errors[:base]).to eq [ "This event has ended, so it is a yes or a no." ]
    end

    it "takes maybe until the event ends" do
      event = create(:event, status: :confirmed, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
      registration = create(:registration, status: :response_requested, event:)

      expect(registration.update(status: :maybe)).to be true
    end

    # One reason is enough: an event somebody concluded takes no answer at all, so naming maybe beside that would describe a choice the member does not have.
    it "gives only the concluded reason on a concluded event that has ended" do
      event = create(:event, status: :concluded, starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
      registration = create(:registration, status: :response_requested, event:)

      registration.update(status: :maybe)

      expect(registration.errors[:base]).to eq [ "This event is concluded or canceled, so it no longer takes replies." ]
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
      expect(described_class.answer?("response_requested")).to be false
    end
  end

  describe "#answered?" do
    # The three statuses are written out rather than read from `Registration::ANSWERS`, which is
    # the constant the method reads: an example iterating it agrees with whatever it holds.
    it "answers true for each of the three answers" do
      expect(build(:registration, status: :yes)).to be_answered
      expect(build(:registration, status: :maybe)).to be_answered
      expect(build(:registration, status: :no)).to be_answered
    end

    it "answers false while the registration is reserved or response_requested" do
      expect(build(:registration, status: :reserved)).not_to be_answered
      expect(build(:registration, status: :response_requested)).not_to be_answered
    end
  end

  describe "#response_due?" do
    it "is due on a question before the event ends" do
      freeze_time do
        ahead = build(:event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)

        expect(build(:registration, event: ahead, status: :response_requested)).to be_response_due
      end
    end

    it "is due on neither a held place nor an answer before the event ends" do
      freeze_time do
        ahead = build(:event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)

        expect(build(:registration, event: ahead, status: :reserved)).not_to be_response_due
        expect(build(:registration, event: ahead, status: :yes)).not_to be_response_due
        expect(build(:registration, event: ahead, status: :maybe)).not_to be_response_due
        expect(build(:registration, event: ahead, status: :no)).not_to be_response_due
      end
    end

    it "is due on a held place, a question and a maybe once the event has ended" do
      freeze_time do
        over = build(:event, starts_at: 2.hours.ago, ends_at: 1.hour.ago)

        expect(build(:registration, event: over, status: :reserved)).to be_response_due
        expect(build(:registration, event: over, status: :response_requested)).to be_response_due
        expect(build(:registration, event: over, status: :maybe)).to be_response_due
      end
    end

    it "is due on neither a yes nor a no once the event has ended" do
      freeze_time do
        over = build(:event, starts_at: 2.hours.ago, ends_at: 1.hour.ago)

        expect(build(:registration, event: over, status: :yes)).not_to be_response_due
        expect(build(:registration, event: over, status: :no)).not_to be_response_due
      end
    end
  end

  describe "#request_response" do
    it "moves a reserved registration to response_requested" do
      registration = create(:registration, status: :reserved)

      expect(registration.request_response).to be true
      expect(registration.reload).to be_response_requested
    end

    it "leaves a requested or answered registration as it was" do
      requested = create(:registration, status: :response_requested)
      answered = create(:registration, event: create(:event, status: :confirmed), status: :yes)

      expect([ requested.request_response, answered.request_response ]).to eq [ false, false ]
      expect([ requested.reload.status, answered.reload.status ]).to eq %w[ response_requested yes ]
    end

    it "leaves a paused or inactive member's held place reserved" do
      paused = create(:registration, member: create(:member, :paused), status: :reserved)
      gone = create(:registration, member: create(:member, :inactive), status: :reserved)

      expect([ paused.request_response, gone.request_response ]).to eq [ false, false ]
      expect([ paused.reload.status, gone.reload.status ]).to eq %w[ reserved reserved ]
    end

    it "leaves a held place on a concluded or canceled event reserved, and emails nobody" do
      concluded = create(:registration, event: create(:event, status: :concluded), status: :reserved)
      canceled = create(:registration, event: create(:event, status: :canceled), status: :reserved)

      expect { concluded.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      expect { canceled.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      expect([ concluded.reload.status, canceled.reload.status ]).to eq %w[ reserved reserved ]
    end

    it "emails the member once their held place moves" do
      registration = create(:registration, status: :reserved)

      expect { registration.request_response }.to have_enqueued_mail(RegistrationMailer, :response_requested).with(registration).once
    end

    it "emails nobody whose response was already requested or who already answered" do
      requested = create(:registration, status: :response_requested)
      answered = create(:registration, event: create(:event, status: :confirmed), status: :yes)

      expect { requested.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      expect { answered.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
    end

    it "emails no paused or inactive member" do
      paused = create(:registration, member: create(:member, :paused), status: :reserved)
      gone = create(:registration, member: create(:member, :inactive), status: :reserved)

      expect { paused.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      expect { gone.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
    end

    it "leaves a pending member's held place reserved, and emails them nothing" do
      pending = create(:registration, member: create(:member, :pending), status: :reserved)

      expect { pending.request_response }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      expect(pending.reload).to be_reserved
    end

    it "emails nobody when the transaction it ran in rolls back" do
      registration = create(:registration, status: :reserved)

      expect {
        described_class.transaction do
          registration.request_response
          raise ActiveRecord::Rollback
        end
      }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
    end
  end
end
