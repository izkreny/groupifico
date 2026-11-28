require "rails_helper"

RSpec.describe Member::Filter do
  let(:reader) { create(:member, :active) }

  def member(*traits, signed_in: true, **attributes)
    create(:member, :active, *traits, user: create(:user, first_signed_in_at: (1.day.ago if signed_in)), group: reader.group, **attributes)
  end

  def ids(filter)
    filter.apply(reader.group.members).ids
  end

  describe ".from" do
    # WHY: #484 AC7. The URL is the only place a filter lives, so a link's parameters are the whole filter.
    it "reads the tab and filters from the URL's parameters" do
      filter = described_class.from(reader, ActionController::Parameters.new(status: "inactive", role: %w[ owner ], manages: "1", not_signed_in: "1"), oversees: true)

      expect([ filter.status, filter.roles, filter.manages?, filter.not_signed_in? ]).to eq [ "inactive", %w[ owner ], true, true ]
    end

    it "is Active with no filters when the URL carries none" do
      filter = described_class.from(reader, ActionController::Parameters.new(group_id: reader.group_id), oversees: true)

      expect([ filter.status, filter.roles, filter.manages?, filter.not_signed_in?, filter.narrowed? ]).to eq [ nil, [], false, false, false ]
    end
  end

  describe ".new" do
    context "with values the reader is not offered" do
      # WHY: #484 AC8. Invited and Inactive are the overseers' tabs, so anyone else asking for them gets the Active list.
      it "drops the Invited and Inactive tabs for a reader who does not oversee the list" do
        expect([ described_class.new(reader, status: "pending").status, described_class.new(reader, status: "inactive").status ]).to eq [ nil, nil ]
      end

      it "keeps the Invited and Inactive tabs for a reader who oversees the list" do
        expect([ described_class.new(reader, oversees: true, status: "pending").status, described_class.new(reader, oversees: true, status: "inactive").status ]).to eq [ "pending", "inactive" ]
      end

      it "drops a tab and a role the list does not offer" do
        filter = described_class.new(reader, oversees: true, status: "active", roles: %w[ owner treasurer ])

        expect([ filter.status, filter.roles ]).to eq [ nil, %w[ owner ] ]
      end

      # WHY: #484 AC4. Who has not signed in yet is the overseers' read, as the row's mark is.
      it "drops the not-signed-in filter for a reader who does not oversee the list" do
        expect(described_class.new(reader, not_signed_in: "1").not_signed_in?).to be false
      end

      it "drops a flag value the sheet does not send" do
        expect([ described_class.new(reader, manages: "yes").manages?, described_class.new(reader, oversees: true, not_signed_in: "true").not_signed_in? ]).to eq [ false, false ]
      end
    end
  end

  describe "#offered_tabs" do
    # WHY: #484 AC2. Active and Paused for every member, Invited and Inactive besides for one who oversees the list.
    it "offers Active and Paused to every reader, and Invited and Inactive besides to one who oversees the list" do
      expect([ described_class.new(reader).offered_tabs.values, described_class.new(reader, oversees: true).offered_tabs.values ]).to eq [ %w[ Active Paused ], %w[ Active Paused Invited Inactive ] ]
    end
  end

  describe "#apply" do
    # WHY: #484 AC2. Active is the tab a plain visit opens on.
    it "lists only the active members on the default tab" do
      active = member
      member(:paused)

      expect(ids(described_class.new(reader))).to contain_exactly(reader.id, active.id)
    end

    it "lists only the members of the tab picked" do
      paused = member(:paused)
      member(:inactive)

      expect(ids(described_class.new(reader, status: "paused"))).to eq [ paused.id ]
    end

    # WHY: #484 AC3 and N5. Roles are rows, so a member holding several matches each of them, once.
    it "narrows the list to the members holding any role picked, each listed once" do
      both = member(roles: [ build(:role, name: "administrator"), build(:role, name: "events_administrator") ])
      member(:members_administrator)

      expect(ids(described_class.new(reader, roles: %w[ administrator events_administrator ]))).to eq [ both.id ]
    end

    # WHY: #484 AC4. "Manages events" is managing at least one of the group's events, whatever its date.
    it "narrows the list to the members who manage one of the group's events" do
      manager = member
      create(:event, :from_the_past, group: reader.group, creator: reader, manager:)
      create(:event, group: reader.group, creator: member)

      expect(ids(described_class.new(reader, manages: "1"))).to eq [ manager.id ]
    end

    # WHY: #484 AC4. "Not signed in yet" reads the fact the row's mark reads.
    it "narrows the list to the members who have never signed in, for a reader who oversees the list" do
      waiting = member(signed_in: false)
      member

      expect(ids(described_class.new(reader, oversees: true, not_signed_in: "1"))).to contain_exactly(reader.id, waiting.id)
    end
  end

  describe "#counts" do
    # WHY: #484 AC12. Each tab counts what it would list with every filter on.
    it "counts each tab's members under the filters that are on" do
      member(:owner)
      member(:owner, :paused)
      member(:paused)

      expect(described_class.new(reader, oversees: true, roles: %w[ owner ]).counts(reader.group.members)).to eq({ nil => 1, "paused" => 1 })
    end
  end

  describe "#chips" do
    # WHY: #484 AC6. Each chip names one filter, in sheet order, with the parameters that remove it alone and keep the tab.
    it "names each filter in sheet order, with the parameters that remove it alone" do
      filter = described_class.new(reader, oversees: true, status: "paused", roles: %w[ administrator owner ], manages: "1", not_signed_in: "1")

      expect(filter.chips).to eq [
        [ "Owner", { status: "paused", role: %w[ administrator ], manages: "1", not_signed_in: "1" } ],
        [ "Administrator", { status: "paused", role: %w[ owner ], manages: "1", not_signed_in: "1" } ],
        [ "Manages events", { status: "paused", role: %w[ owner administrator ], not_signed_in: "1" } ],
        [ "Not signed in yet", { status: "paused", role: %w[ owner administrator ], manages: "1" } ]
      ]
    end
  end

  describe "#cleared" do
    it "keeps the tab and nothing else" do
      expect(described_class.new(reader, status: "paused", roles: %w[ owner ], manages: "1").cleared).to eq({ status: "paused" })
    end
  end
end
