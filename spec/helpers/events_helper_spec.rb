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

  describe "#event_statuses" do
    it "pairs each enum status with its upcased label" do
      pairs = [ %w[ UNCONFIRMED unconfirmed ], %w[ CONFIRMED confirmed ], %w[ CONCLUDED concluded ], %w[ CANCELED canceled ] ]

      expect(helper.event_statuses).to match_array(pairs)
    end
  end
end
