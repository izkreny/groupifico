require "rails_helper"

# Outside `spec/system`, and out of a bare `bin/rspec` and of `bin/ci`, by the exclude pattern in
# `.rspec`; naming the folder is what runs it, `bin/rspec spec/styleguide`.
#
# The page sets its themes itself, one twin of each section under each, so both are on every load.
# What makes "under each theme" falsifiable is the twin's own `color-scheme`, the property each
# daisyUI theme sets, read as `ColourSchemeHelper#rendered_colour_scheme` reads the root's.
RSpec.describe "The styleguide", type: :system do
  it "paints the hero card and the lit RSVP pill in the light twin" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as planted_member("Ana Horvat").user

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic]')).colorScheme")).to eq "light"
    expect(page).to paint "[data-theme=organic] .card"
    expect(page).to paint "[data-theme=organic] .join .btn-primary"
  end

  it "paints the same two in the dark twin" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as planted_member("Ana Horvat").user

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic-dark]')).colorScheme")).to eq "dark"
    expect(page).to paint "[data-theme=organic-dark] .card"
    expect(page).to paint "[data-theme=organic-dark] .join .btn-primary"
  end

  # The hex a row prints is read from the stylesheet, so this is what holds the printed value to the colour the theme paints.
  it "paints every swatch in the colour its row prints, in both twins" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    rows = find("section", text: "Colour tokens").evaluate_script(<<~JS)
      [...this.querySelectorAll("[data-theme] tbody tr")].map(row => [row.querySelector("td:nth-child(3)").textContent, getComputedStyle(row.querySelector("td:nth-child(2) span")).backgroundColor])
    JS
    expect(rows.size).to eq 40
    expect(rows.reject { |hex, painted| painted == "rgb(#{hex.delete_prefix("#").scan(/../).map { it.to_i(16) }.join(", ")})" }).to be_empty
  end

  # The token tables are wide, so their twins sit one above the other at every width rather than side by side.
  it "stacks the light colour tokens above the dark ones on a wide screen" do
    plant_styleguide_group
    sign_in_as create(:user)
    page.driver.resize(1440, 900)

    visit styleguide_path

    light, dark = %w[ organic organic-dark ].map { |theme| find("section", text: "Colour tokens").find("[data-theme=#{theme}]").evaluate_script("this.getBoundingClientRect().toJSON()") }
    expect(dark["top"]).to be >= light["bottom"]
  end

  it "fits a phone's width, the token tables scrolling inside their twins" do
    plant_styleguide_group
    sign_in_as create(:user)
    page.driver.resize(390, 844)

    visit styleguide_path

    expect(page).to have_css "h1", text: "Styleguide"
    expect(page.evaluate_script("document.documentElement.scrollWidth - window.innerWidth")).to be <= 0
  end

  # The views set body text on all three surfaces, where the token table tags the base content against the page alone and leaves the surfaces' own rows untagged. Probes rather than the page's own markup, so what is measured is the palette and not whichever section happens to sit on a surface.
  it "reads the body text at AA on every surface, in both twins" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    ratios = %w[ organic organic-dark ].product(%w[ base-100 base-200 base-300 ]).to_h do |theme, surface|
      page.execute_script(<<~JS, theme, surface)
        document.querySelector(`[data-theme=${arguments[0]}]`).insertAdjacentHTML("beforeend", `<div class="bg-${arguments[1]}"><span id="probe-${arguments[0]}-${arguments[1]}">Aa</span></div>`)
      JS
      [ "#{theme} #{surface}", text_contrast("#probe-#{theme}-#{surface}") ]
    end
    expect(ratios.select { |_surface, ratio| ratio < ContrastHelper::WCAG_AA }).to be_empty
  end

  it "sets the type ladder's titles in Caprasimo and its text in Figtree" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    ladder = find("section", text: "Type ladder")
    expect(ladder.all(".font-heading").map { it.evaluate_script("getComputedStyle(this).fontFamily") }).to match [ a_string_starting_with("Caprasimo") ] * 8
    expect(ladder.all("p:not(.font-heading)").map { it.evaluate_script("getComputedStyle(this).fontFamily") }).to match [ a_string_starting_with("Figtree") ] * 6
  end

  it "keeps the member switcher in view while the page scrolls" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    expect(find_by_id("member_switcher").evaluate_script("this.getBoundingClientRect().top")).to eq 0
    expect(page.evaluate_script("window.scrollY")).to be > 0
  end

  # The owner's Edit group link is drawn by the server alone, so it appearing is what proves the pick submitted.
  it "signs in as the member picked in the switcher" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as create(:user)

    visit styleguide_path
    select "Ana Horvat - owner, active", from: "Signed in as"

    expect(page).to have_css "a[aria-label='Edit group']"
    expect(page).to have_select "Signed in as", selected: "Ana Horvat - owner, active"
  end

  # The owner gets the gated sections drawn above the member rows that a user outside the group does not, so a kept pixel offset alone would land several sections higher.
  it "keeps the same section in view through a switch that draws sections above it" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as create(:user)
    member_rows_top = "[...document.querySelectorAll('section')].find(section => section.querySelector('h2').textContent == 'Member rows, owner and paused').getBoundingClientRect().top"

    visit styleguide_path
    page.execute_script("window.scrollBy(0, #{member_rows_top} - 100)")
    select "Ana Horvat - owner, active", from: "Signed in as"

    expect(page).to have_css "a[aria-label='Edit group']"
    expect(page.evaluate_script(member_rows_top)).to be_within(1).of(100)
  end

  # One audit covers both themes, since both twins of every section are on the page. Signed in as the owner, whose policies draw every control the page holds.
  it "has no accessibility violations" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as planted_member("Ana Horvat").user
    prefer_colour_scheme :light

    visit styleguide_path

    expect(page).to have_css "h1", text: "Styleguide"
    expect(page).to be_accessible
  end

  it "names the seed command, accessibly, without the styleguide group" do
    sign_in_as create(:user)
    prefer_colour_scheme :light

    visit styleguide_path

    expect(page).to have_text "bin/rails db:seed:replant"
    expect(page).to be_accessible
  end
end
