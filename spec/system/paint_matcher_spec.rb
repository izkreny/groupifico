require "rails_helper"

# The matcher's own control. An uncompiled utility class and a colour identical to its background
# both score exactly 1.0, so a passing control proves two things at once: that the matcher measures
# something real, and that the class under test survived the Tailwind build. Per `.agents/testing.md`
# this was watched failing, against a class that does compile, before it was trusted.
RSpec.describe "The paint matcher", type: :system do
  before do
    visit new_session_path
  end

  it "does not report a class Tailwind never compiled as painting" do
    append_probe "bg-notacolour-999"

    expect(page).not_to paint "#probe"
  end

  # `btn btn-primary` rather than a utility like `bg-error`: Tailwind compiles only the classes it
  # finds in the sources it scans, and this page's own submit button carries these two, so they are
  # certain to be in the build. That is the same fact the negative case above depends on, read from
  # the other side.
  it "reports a compiled class as painting" do
    append_probe "btn btn-primary"

    expect(page).to paint "#probe"
  end

  private
    # Injected rather than routed. A test-only route would be application code that exists for the
    # suite, and the class under test has to reach the browser through the real stylesheet either
    # way, which is the half of this the matcher is checking.
    def append_probe(classes)
      page.execute_script(<<~JAVASCRIPT, classes)
        const probe = document.createElement("div");
        probe.id = "probe";
        probe.className = arguments[0];
        probe.textContent = "probe";
        document.body.appendChild(probe);
      JAVASCRIPT
    end
end
