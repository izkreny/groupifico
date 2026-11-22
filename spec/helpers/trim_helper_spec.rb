require 'rails_helper'

RSpec.describe TrimHelper, type: :helper do
  describe "#trimmed" do
    it "draws the value in the named tag, trimmed alongside the classes it is given" do
      expect(helper.trimmed("Riverside Choir", :h1, class: "font-heading"))
        .to eq '<h1 title="Riverside Choir" class="truncate font-heading">Riverside Choir</h1>'
    end

    it "carries the whole value in its title, so a desktop pointer reads what the ellipsis hides" do
      expect(helper.trimmed("The Extraordinarily Long Named Riverside Community Choir"))
        .to eq '<span title="The Extraordinarily Long Named Riverside Community Choir" class="truncate">The Extraordinarily Long Named Riverside Community Choir</span>'
    end
  end
end
