require "rails_helper"

# The helper's own control, on the same terms as `spec/system/paint_matcher_spec.rb`: both build
# from `spec/support/contrast.rb`, so what that file gets wrong they get wrong together, and each
# needs a case of its own that is watched failing. Per `.agents/testing.md` both examples below were
# watched failing before they were trusted.
#
# The probe's opacity is an inline style rather than a utility class, which is the one place this
# control differs from the paint matcher's: that one is also checking that Tailwind compiled the
# class, and this one is checking arithmetic the helper does on whatever the browser computed.
RSpec.describe "The contrast helper", type: :system do
  before do
    visit new_session_path
  end

  # What only this helper does: fold the opacity an element inherits into its colour before
  # comparing with the surface. axe-core does not, which is the whole reason the helper exists.
  it "counts an ancestor's opacity against the text, where the colour alone would not" do
    append_probe opacity: 0.05

    expect(text_contrast("#probe span")).to be < ContrastHelper::WCAG_AA
  end

  # The selector reaches the script as an argument rather than as interpolated source, so a double
  # quote inside it is data. Every attribute selector carries two.
  it "measures a selector carrying double quotes" do
    append_probe opacity: 1

    expect(text_contrast('[data-probe="yes"] span')).to be >= ContrastHelper::WCAG_AA
  end

  private
    # Injected rather than routed, for the reason the paint matcher's own control gives: a test-only
    # route would be application code that exists for the suite.
    def append_probe(opacity:)
      page.execute_script(<<~JAVASCRIPT, opacity)
        const probe = document.createElement("div");
        probe.id = "probe";
        probe.dataset.probe = "yes";
        probe.style.opacity = arguments[0];
        probe.innerHTML = "<span>probe</span>";
        document.body.appendChild(probe);
      JAVASCRIPT
    end
end
