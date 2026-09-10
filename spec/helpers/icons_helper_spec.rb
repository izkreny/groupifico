require 'rails_helper'

RSpec.describe IconsHelper, type: :helper do
  describe "#icon" do
    it "draws the legend's glyph inline, coloured by the surrounding text" do
      map_pin = File.read(Rails.root.join("app/assets/svg/icons/heroicons/outline/map-pin.svg"))[/ d="([^"]+)"/, 1]

      expect(helper.icon(:where)).to include(map_pin).and include('stroke="currentColor"')
    end

    it "strokes at 2, the weight the legend overrides Heroicons' own 1.5 to" do
      expect(helper.icon(:where)).to include('stroke-width="2"')
    end

    it "strokes the back chevron at 2.5, the one glyph the legend draws heavier" do
      expect(helper.icon(:back)).to include('stroke-width="2.5"')
    end

    # Restoring the gem's own `size-6` default would pass here and paint nothing: it lives in Ruby,
    # where Tailwind's source scanner never reads it, so the class reaches the markup and the
    # stylesheet has no rule behind it. A call site states its size instead, in the template.
    it "sizes nothing by default, leaving the size to the markup Tailwind actually scans" do
      expect(helper.icon(:where)).not_to include("class=")
    end

    it "hides the glyph from assistive technology when nothing labels it" do
      expect(helper.icon(:where)).to include('aria-hidden="true"')
      expect(helper.icon(:where)).not_to include("aria-label")
    end

    it "names the glyph to assistive technology when a label is passed" do
      expect(helper.icon(:delete, label: "Take off")).to include('aria-label="Take off"')
        .and include('role="img"')
        .and include('aria-hidden="false"')
    end

    it "raises for a meaning the legend does not map" do
      expect { helper.icon(:sparkles) }.to raise_error(KeyError)
    end
  end

  describe "#status_icon" do
    it "draws the glyph the legend gives an event's status" do
      no_symbol = File.read(Rails.root.join("app/assets/svg/icons/heroicons/outline/no-symbol.svg"))[/ d="([^"]+)"/, 1]

      expect(helper.status_icon(build(:event, status: :canceled))).to include(no_symbol)
    end

    it "draws the glyph the legend gives a registration's status" do
      clock = File.read(Rails.root.join("app/assets/svg/icons/heroicons/outline/clock.svg"))[/ d="([^"]+)"/, 1]

      expect(helper.status_icon(build(:registration, status: :maybe))).to include(clock)
    end

    it "raises for a status the legend does not map" do
      event = build(:event, status: "bogus")

      expect { helper.status_icon(event) }.to raise_error(KeyError)
    end
  end
end
