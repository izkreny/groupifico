require 'rails_helper'

RSpec.describe TrimHelper, type: :helper do
  describe "#trimmed" do
    it "draws the value in the named tag, trimmed alongside the classes it is given" do
      tag = Nokogiri::HTML.fragment(helper.trimmed("Riverside Choir", :h1, class: "font-heading")).at("h1")

      expect(tag.text).to eq "Riverside Choir"
      expect(tag["class"].split).to contain_exactly("truncate", "font-heading")
    end

    it "carries the whole value in its title, so a desktop pointer reads what the ellipsis hides" do
      tag = Nokogiri::HTML.fragment(helper.trimmed("The Extraordinarily Long Named Riverside Community Choir")).at("span")

      expect(tag["title"]).to eq "The Extraordinarily Long Named Riverside Community Choir"
    end

    it "clamps the value at two lines rather than one when asked" do
      tag = Nokogiri::HTML.fragment(helper.trimmed("Spring concert", :a, lines: 2, class: "link")).at("a")

      expect(tag["class"].split).to contain_exactly("line-clamp-2", "link")
    end
  end
end
