require "rails_helper"

RSpec.describe StyleguidesHelper, type: :helper do
  describe "#theme_colours" do
    it "reads each theme's colour tokens from the stylesheet" do
      expect(helper.theme_colours("organic")).to include "primary" => "#8c491a", "base-content" => "#201e1d"
      expect(helper.theme_colours("organic-dark")).to include "primary" => "#e09675", "base-content" => "#f9f4ed"
    end

    it "reads all twenty of daisyUI's colour tokens for a theme" do
      expect(helper.theme_colours("organic").size).to eq 20
    end
  end

  # The literals are WCAG's published extremes and the ratio every contrast checker gives #777 on white.
  describe "#contrast_ratio" do
    it "rates black on white at 21:1" do
      expect(helper.contrast_ratio("#000000", "#ffffff")).to be_within(0.005).of(21)
    end

    it "rates #777 on white at 4.48:1, whichever comes first" do
      expect(helper.contrast_ratio("#777777", "#ffffff")).to be_within(0.005).of(4.48)
      expect(helper.contrast_ratio("#ffffff", "#777777")).to be_within(0.005).of(4.48)
    end

    it "rates a colour on itself at 1:1" do
      expect(helper.contrast_ratio("#8c491a", "#8c491a")).to be_within(0.005).of(1)
    end
  end

  # The thresholds are WCAG AA's: 4.5:1 for text, and 3:1 for large text and interface chrome.
  describe "#contrast_ratio_tag" do
    it "prints a ratio that clears AA for text plainly" do
      expect(helper.contrast_ratio_tag(4.5)).to eq "<span>4.50:1</span>"
    end

    it "tags a ratio that clears only large text as a warning" do
      expect(helper.contrast_ratio_tag(3.0)).to eq %(<span class="badge badge-xs badge-warning">3.00:1</span>)
    end

    it "tags a ratio below 3:1 as an error" do
      expect(helper.contrast_ratio_tag(2.99)).to eq %(<span class="badge badge-xs badge-error">2.99:1</span>)
    end

    it "prints any ratio plainly when it is not to be flagged" do
      expect(helper.contrast_ratio_tag(1.2, flagged: false)).to eq "<span>1.20:1</span>"
    end
  end

  describe "#contrast_pair" do
    it "reads a colour against its content colour and back" do
      expect(helper.contrast_pair("primary")).to eq "primary-content"
      expect(helper.contrast_pair("primary-content")).to eq "primary"
    end

    it "reads every base against the base content, and the base content against the page" do
      expect(helper.contrast_pair("base-200")).to eq "base-content"
      expect(helper.contrast_pair("base-content")).to eq "base-100"
    end
  end
end
