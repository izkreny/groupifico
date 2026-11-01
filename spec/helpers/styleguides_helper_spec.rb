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

  describe "#app_colours" do
    it "reads the app's own colour tokens, apart from daisyUI's, from the stylesheet" do
      expect(helper.app_colours).to eq "icon-muted" => "color-mix(in oklab, var(--color-base-content) 60%, transparent)", "muted" => "color-mix(in oklab, var(--color-base-content) 70%, transparent)"
    end
  end

  # #757068 by hand: each channel of the light ink, #201e1d, at 60% over the light page, #f5ead8.
  describe "#app_colour_hex" do
    it "is the colour an app token's mix lands on over the theme's page" do
      expect(helper.app_colour_hex("organic", "color-mix(in oklab, var(--color-base-content) 60%, transparent)")).to eq "#757068"
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

    it "prints a surface's ratio plainly, however low" do
      expect(helper.contrast_ratio_tag(1.2, token: "base-200")).to eq "<span>1.20:1</span>"
    end

    it "tags the base content's ratio, since the body text is read against the surfaces" do
      expect(helper.contrast_ratio_tag(3.8, token: "base-content")).to eq %(<span class="badge badge-xs badge-warning">3.80:1</span>)
    end
  end

  # The base content is the body text, so it is read against the surfaces like any other colour, and only the three surfaces themselves go unflagged.
  describe "#surface?" do
    it "counts the three bases as surfaces" do
      expect(%w[ base-100 base-200 base-300 ].map { helper.surface?(it) }).to eq [ true, true, true ]
    end

    it "counts the base content, the body text, as a colour" do
      expect(helper.surface?("base-content")).to be false
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

  describe "#member_switch_choices" do
    it "labels each member by name, then their role tags in Role::NAMES order, then their status" do
      user = create(:user, :with_full_profile, first_name: "Ana", last_name: "Horvat")
      member = create(:member, :paused, user:, roles: [ build(:role, name: "events_administrator"), build(:role, name: "owner") ])

      expect(helper.member_switch_choices([ member ])).to eq [ [ "Ana Horvat - owner, events admin, paused", member.id ] ]
    end
  end
end
