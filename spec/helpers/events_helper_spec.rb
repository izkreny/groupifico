require 'rails_helper'

RSpec.describe EventsHelper, type: :helper do
  describe "#answer_prompt" do
    it "asks in the present about an event still ahead" do
      freeze_time do
        expect(helper.answer_prompt(build(:event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now))).to eq "Are you coming?"
      end
    end

    it "asks in the past about an event that has ended" do
      freeze_time do
        expect(helper.answer_prompt(build(:event, starts_at: 2.hours.ago, ends_at: 1.hour.ago))).to eq "Did you go?"
      end
    end
  end

  describe "#event_kicker" do
    it "counts down to an event that has not started" do
      freeze_time do
        event = build(:event, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

        expect(helper.event_kicker(event)).to eq "Next up · in 2 days"
      end
    end

    # The distance to the end rather than to the start: `time_ago_in_words` measures a distance and
    # never a direction, so the old line read "in about 1 hour" about an hour that had already gone.
    it "counts down to the end of an event that is running" do
      freeze_time do
        event = build(:event, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

        expect(helper.event_kicker(event)).to eq "Happening now · ends in about 1 hour"
      end
    end
  end

  describe "#event_credits" do
    it "names the manager and the creator, joined by a dot" do
      alice = create(:member, user: create(:user, :with_full_profile, first_name: "Alice", last_name: "Bird"))
      ben = create(:member, group: alice.group, user: create(:user, :with_full_profile, first_name: "Ben", last_name: "Cole"))
      event = create(:event, group: alice.group, creator: alice, manager: ben)

      expect(Nokogiri::HTML(helper.event_credits(event)).text).to eq "Managed by Ben C. · Created by Alice B."
    end

    it "leaves the manager half out of an event with no manager" do
      alice = create(:member, user: create(:user, :with_full_profile, first_name: "Alice", last_name: "Bird"))
      event = create(:event, group: alice.group, creator: alice)

      expect(Nokogiri::HTML(helper.event_credits(event)).text).to eq "Created by Alice B."
    end

    # A creator removed from the group leaves `creator_id` pointing at nobody, since the column
    # carries no foreign key, and with no manager either there is nobody left to credit.
    it "is nil when neither a manager nor the creator is there to name" do
      event = create(:event)
      event.creator.destroy!

      expect(helper.event_credits(event.reload)).to be_nil
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
