require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe "#group_type" do
    it "is choir for the chorifico.com domain" do
      expect(described_class.new("chorifico.com").group_type).to eq("choir")
    end

    it "is general for a domain that carries no brand" do
      expect(described_class.new("example.com").group_type).to eq("general")
    end

    it "is general for localhost" do
      expect(described_class.new("localhost").group_type).to eq("general")
    end

    # `request.domain` answers nil for a bare IP, so nil reaches here in production rather than
    # only from `Current.brand`'s default.
    it "is general when there is no domain at all" do
      expect(described_class.new(nil).group_type).to eq("general")
    end

    # Nothing upstream downcases the `Host` header, and hostnames are case-insensitive, so a
    # client that does not lowercase it would otherwise miss the mapping.
    it "is choir whatever case the domain arrives in" do
      expect(described_class.new("ChoRifico.COM").group_type).to eq("choir")
    end
  end

  describe "#name" do
    it "is Groupifico for a domain that carries no brand" do
      expect(described_class.new("example.com").name).to eq("Groupifico")
    end

    it "is Chorifico for the chorifico.com domain" do
      expect(described_class.new("chorifico.com").name).to eq("Chorifico")
    end

    it "is Chorifico whatever case the domain arrives in" do
      expect(described_class.new("ChoRifico.COM").name).to eq("Chorifico")
    end

    it "is Groupifico when there is no domain at all" do
      expect(described_class.new(nil).name).to eq("Groupifico")
    end
  end

  describe "#tagline" do
    it "asks about rehearsal on the chorifico.com domain" do
      expect(described_class.new("chorifico.com").tagline).to eq("Who's coming to rehearsal.")
    end

    it "asks about rehearsal whatever case the domain arrives in" do
      expect(described_class.new("ChoRifico.COM").tagline).to eq("Who's coming to rehearsal.")
    end

    it "asks about the next event for a domain that carries no brand" do
      expect(described_class.new("example.com").tagline).to eq("Who's coming to the next event.")
    end

    it "asks about the next event when there is no domain at all" do
      expect(described_class.new(nil).tagline).to eq("Who's coming to the next event.")
    end
  end
end
