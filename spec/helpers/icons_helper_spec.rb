require 'rails_helper'

RSpec.describe IconsHelper, type: :helper do
  # The first `d` of a synced Heroicons file, which is what proves which drawing an icon came from.
  def path_of(variant, name)
    File.read(Rails.root.join("app/assets/svg/icons/heroicons/#{variant}/#{name}.svg"))[/ d="([^"]+)"/, 1]
  end

  describe "#icon" do
    it "draws the legend's glyph inline, filled in the surrounding text's colour" do
      expect(helper.icon(:where, class: "size-6")).to include(path_of("solid", "map-pin")).and include('fill="currentColor"')
    end

    # Heroicons draws its filled set on its own grid at each size, so each size class takes the drawing made for it.
    it "draws the 20px and 16px sizes from the sets drawn for them" do
      expect([ helper.icon(:where, class: "size-5"), helper.icon(:where, class: "size-4") ])
        .to match [ including(path_of("mini", "map-pin")), including(path_of("micro", "map-pin")) ]
    end

    # The size class is what picks the drawing, so a call that states none has nothing to draw from. Restoring the gem's own `size-6` default would not help either: it lives in Ruby, where Tailwind's source scanner never reads it.
    it "raises for an icon whose class states no size" do
      expect { helper.icon(:where) }.to raise_error(ArgumentError, /size-6/)
    end

    it "hides the glyph from assistive technology when nothing labels it" do
      expect(helper.icon(:where, class: "size-4")).to include('aria-hidden="true"')
      expect(helper.icon(:where, class: "size-4")).not_to include("aria-label")
    end

    it "names the glyph to assistive technology when a label is passed" do
      expect(helper.icon(:delete, label: "Take off", class: "size-4")).to include('aria-label="Take off"')
        .and include('role="img"')
        .and include('aria-hidden="false"')
    end

    it "raises for a meaning the legend does not map" do
      expect { helper.icon(:sparkles, class: "size-4") }.to raise_error(KeyError)
    end
  end

  describe "#status_icon" do
    it "draws the glyph the legend gives an event's status" do
      expect(helper.status_icon(build(:event, status: :canceled), class: "size-6")).to include(path_of("solid", "no-symbol"))
    end

    it "draws the glyph the legend gives a registration's status" do
      expect(helper.status_icon(build(:registration, status: :maybe), class: "size-6")).to include(path_of("solid", "clock"))
    end

    it "raises for a status the legend does not map" do
      event = build(:event, status: "bogus")

      expect { helper.status_icon(event, class: "size-6") }.to raise_error(KeyError)
    end
  end
end
