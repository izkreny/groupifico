require "rails_helper"

# The matcher's own control, in `paint_matcher_spec.rb`'s shape and for the same reason: an
# assertion never watched failing cannot be told from one that cannot fail. Per `.agents/testing.md`
# it was watched red, by giving the probe an `alt` attribute, before the matcher was trusted.
#
# The probe is an image with no alternative text because `image-alt` is tagged at WCAG 2.0 level A,
# which makes this control what holds `AxeMatcher::STANDARD` to the whole cumulative standard: name
# only the rules 2.1 added at AA and this page stays green with the probe sitting on it.
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
end
