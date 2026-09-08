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

  # Not a test of `Brand` so much as of the assumption it is built on: it takes a domain because
  # `request.domain` has already collapsed the subdomains, and a `Brand` fed a host would answer
  # general on every one of them.
  describe "the domain the request hands it" do
    it "collapses a subdomain onto the branded domain" do
      domain = ActionDispatch::Http::URL.extract_domain("www.chorifico.com", 1)

      expect(described_class.new(domain).group_type).to eq("choir")
    end

    it "collapses a nested subdomain onto the branded domain" do
      domain = ActionDispatch::Http::URL.extract_domain("api.www.chorifico.com", 1)

      expect(described_class.new(domain).group_type).to eq("choir")
    end

    it "has no domain to offer for a bare IP" do
      domain = ActionDispatch::Http::URL.extract_domain("127.0.0.1", 1)

      expect(described_class.new(domain).group_type).to eq("general")
    end
  end
end
