require "rails_helper"

# Outside `spec/system`, and out of a bare `bin/rspec` and of `bin/ci`, by the exclude pattern in
# `.rspec`; naming the folder is what runs it, `bin/rspec spec/styleguide`.
#
# The page sets its themes itself, one twin of each section under each, so both are on every load.
# What makes "under each theme" falsifiable is the twin's own `color-scheme`, the property each
# daisyUI theme sets, read as `ColourSchemeHelper#rendered_colour_scheme` reads the root's.
RSpec.describe "The styleguide", type: :system do
  it "paints the hero card and the lit RSVP pill in the light twin" do
    sign_in_as create(:user)

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic]')).colorScheme")).to eq "light"
    expect(page).to paint "[data-theme=organic] .card"
    expect(page).to paint "[data-theme=organic] .join .btn-primary"
  end

  it "paints the same two in the dark twin" do
    sign_in_as create(:user)

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic-dark]')).colorScheme")).to eq "dark"
    expect(page).to paint "[data-theme=organic-dark] .card"
    expect(page).to paint "[data-theme=organic-dark] .join .btn-primary"
  end

  # One audit covers both themes, since both twins of every section are on the page.
  it "has no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :light

    visit styleguide_path

    expect(page).to have_css "h1", text: "Styleguide"
    expect(page).to be_accessible
  end
end
