require "rails_helper"

# The matcher's own control, in `paint_matcher_spec.rb`'s shape and for the same reason: an
# assertion never watched failing cannot be told from one that cannot fail. Per `.agents/testing.md`
# it was watched red, by giving the probe an `alt` attribute, before the matcher was trusted.
#
# Two probes, at the two ends of the cumulative range `AxeMatcher::STANDARD` names: `image-alt` is
# tagged at WCAG 2.0 level A and `autocomplete-valid` at 2.1 level AA, so narrowing that list to
# either end alone turns one of them green and this file red. The two levels between them are
# pinned by nothing, deliberately - a probe apiece would be four couplings to axe's own tag
# assignments, which move between engine versions, to pin a policy the plan calls a judgement
# rather than a gate.
RSpec.describe "The accessibility matcher", type: :system do
  before do
    visit new_session_path
  end

  it "reports an image carrying no alternative text" do
    append_image_without_alt

    # Positive first, and not only to satisfy `Capybara/RSpec/NegationMatcherAfterVisit`: an
    # unresolved navigation would leave the probe on a blank page that violates other rules, and
    # the negation below would then pass without ever seeing this one.
    expect(page).to have_css "img:not([alt])"
    expect(page).not_to be_accessible
  end

  it "reports an input carrying an unusable autocomplete token" do
    append_input_with_invalid_autocomplete

    expect(page).to have_css "input[autocomplete='not-a-token']"
    expect(page).not_to be_accessible
  end

  # The other half of the pair, and the load-bearing half: a page this suite audits is expected to
  # be clean, so a matcher that reported violations everywhere would be as useless as one that
  # reported none. This is also what catches the navigation the example above guards against.
  it "reports a page carrying no violation as accessible" do
    expect(page).to be_accessible
  end

  private
    # Injected rather than routed, exactly as the paint matcher's probe is: a test-only view would
    # be application code that exists for the suite. The source is a 1x1 transparent GIF inline, so
    # nothing here reaches the network that `spec/rails_helper.rb` closes.
    def append_image_without_alt
      page.execute_script(<<~JAVASCRIPT)
        const image = document.createElement("img");
        image.src = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
        document.body.appendChild(image);
      JAVASCRIPT
    end

    # The other end of the range. An unusable token rather than a missing attribute, because
    # `autocomplete-valid` is about the value: omitting it entirely violates nothing.
    #
    # The `aria-label` is what makes this probe pin its own tag. Without a name the input also
    # violates `label`, which is tagged at WCAG 2.0 level A, so the example went red on the tag it
    # exists to prove is *not* enough - watched happening, which is the whole reason the narrowing
    # is run rather than reasoned about.
    def append_input_with_invalid_autocomplete
      page.execute_script(<<~JAVASCRIPT)
        const input = document.createElement("input");
        input.autocomplete = "not-a-token";
        input.setAttribute("aria-label", "probe");
        document.body.appendChild(input);
      JAVASCRIPT
    end
end
