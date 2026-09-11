require 'rails_helper'

RSpec.describe EventsHelper, type: :helper do
  describe "#event_schedule" do
    context "when the event starts and ends on the same day" do
      it "formats the end time as a bare time, without repeating the date" do
        event = build(:event, starts_at: Time.zone.parse("2026-01-01 10:00"), ends_at: Time.zone.parse("2026-01-01 12:00"))

        expect(helper.event_schedule(event)).to eq "2026-01-01 10:00 – 12:00"
      end
    end

    context "when the event spans more than one day" do
      it "formats the end time with its own date" do
        event = build(:event, starts_at: Time.zone.parse("2026-01-01 10:00"), ends_at: Time.zone.parse("2026-01-02 12:00"))

        expect(helper.event_schedule(event)).to eq "2026-01-01 10:00 – 2026-01-02 12:00"
      end
    end
  end

  describe "#event_schedule_range" do
    context "when the event starts and ends on the same day" do
      it "prints the day, then the time range" do
        event = build(:event, starts_at: Time.zone.parse("2026-09-02 19:00"), ends_at: Time.zone.parse("2026-09-02 21:00"))

        expect(helper.event_schedule_range(event)).to eq "Wed 2 Sep · 19:00–21:00"
      end
    end

    context "when the event spans more than one day" do
      it "prints the second day as well" do
        event = build(:event, starts_at: Time.zone.parse("2026-09-02 19:00"), ends_at: Time.zone.parse("2026-09-03 02:00"))

        expect(helper.event_schedule_range(event)).to eq "Wed 2 Sep · 19:00 – Thu 3 Sep · 02:00"
      end
    end
  end

  describe "#event_schedule_start" do
    it "prints the day and the start time, for the compact row" do
      event = build(:event, starts_at: Time.zone.parse("2026-09-07 10:00"), ends_at: Time.zone.parse("2026-09-07 11:30"))

      expect(helper.event_schedule_start(event)).to eq "Mon 7 Sep · 10:00"
    end
  end

  describe "#event_status_line" do
    it "folds the category into the status" do
      event = build(:event, status: :confirmed, category: :rehearsal)

      expect(helper.event_status_line(event)).to eq "Confirmed rehearsal"
    end

    it "leaves the status standing alone when the category is other" do
      event = build(:event, status: :confirmed, category: :other)

      expect(helper.event_status_line(event)).to eq "Confirmed"
    end
  end

  describe "#said_yes_line" do
    it "names everyone who said yes" do
      event = create(:event)
      alice = create(:member, group: event.group, user: create(:user, :with_full_profile, first_name: "Alice", last_name: "Brown"))
      ben   = create(:member, group: event.group, user: create(:user, :with_full_profile, first_name: "Ben", last_name: "Cole"))
      create(:registration, event:, member: alice, status: :yes)
      create(:registration, event:, member: ben, status: :yes)
      create(:registration, event:, member: create(:member, group: event.group), status: :no)

      expect(helper.said_yes_line(event.reload)).to eq "Alice Brown and Ben Cole said yes"
    end

    it "is nil when nobody has said yes" do
      event = create(:event)
      create(:registration, event:, member: create(:member, group: event.group), status: :invited)

      expect(helper.said_yes_line(event.reload)).to be_nil
    end
  end

  describe "#event_statuses" do
    it "pairs each enum status with its upcased label, in enum order" do
      pairs = [ %w[ UNCONFIRMED unconfirmed ], %w[ CONFIRMED confirmed ], %w[ CONCLUDED concluded ], %w[ CANCELED canceled ] ]

      expect(helper.event_statuses).to eq(pairs)
    end
  end
end
