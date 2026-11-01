require "rails_helper"

# Outside `spec/system`, and out of a bare `bin/rspec` and of `bin/ci`, by the exclude pattern in
# `.rspec`; naming the folder is what runs it, `bin/rspec spec/styleguide`.
#
# The page sets its themes itself, one twin of each section under each, so both are on every load.
# What makes "under each theme" falsifiable is the twin's own `color-scheme`, the property each
# daisyUI theme sets, read as `ColourSchemeHelper#rendered_colour_scheme` reads the root's.
RSpec.describe "The styleguide", type: :system do
  it "paints the hero card and the lit reply pill in the light twin" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as planted_member("Ana Horvat").user

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic]')).colorScheme")).to eq "light"
    expect(page).to paint "[data-theme=organic] .card"
    expect(page).to paint "[data-theme=organic] .btn-success[aria-current='true']"
  end

  it "paints the same two in the dark twin" do
    plant_styleguide_group(manager: "Ana Horvat")
    sign_in_as planted_member("Ana Horvat").user

    visit styleguide_path

    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme=organic-dark]')).colorScheme")).to eq "dark"
    expect(page).to paint "[data-theme=organic-dark] .card"
    expect(page).to paint "[data-theme=organic-dark] .btn-success[aria-current='true']"
  end

  # The hex a row prints is read from the stylesheet, so this is what holds the printed value to the colour the theme paints.
  it "paints every swatch in the colour its row prints, in both twins" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    rows = find("section", text: "Colour tokens").evaluate_script(<<~JS)
      [...this.querySelectorAll("[id^=daisyui_tokens] tr")].map(row => [row.querySelector("td:nth-child(3)").textContent, getComputedStyle(row.querySelector("td:nth-child(2) span")).backgroundColor])
    JS
    expect(rows.size).to eq 40
    expect(rows.reject { |hex, painted| painted == "rgb(#{hex.delete_prefix("#").scan(/../).map { it.to_i(16) }.join(", ")})" }).to be_empty
  end

  # The token tables are wide, so their twins sit one above the other at every width rather than side by side.
  it "stacks the light colour tokens above the dark ones on a wide screen" do
    plant_styleguide_group
    sign_in_as create(:user)
    page.current_window.resize_to(1440, 900)

    visit styleguide_path

    light, dark = %w[ organic organic-dark ].map do |theme|
      within("section", text: "Colour tokens") { find("[data-theme=#{theme}]").evaluate_script("this.getBoundingClientRect().toJSON()") }
    end
    expect(dark["top"]).to be >= light["bottom"]
  end

  it "fits a phone's width, the token tables scrolling inside their twins" do
    plant_styleguide_group
    sign_in_as create(:user)
    page.current_window.resize_to(390, 844)

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

  # A soft alert's words and an icon set straight on the page both read the status colour against the ground, so each has to hold AA there. Probes with the colour inline, since nothing compiles a `text-warning` for a class to reach.
  it "reads every status colour at AA straight on the page, in both twins" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    ratios = %w[ organic organic-dark ].product(%w[ info success warning error ]).to_h do |theme, status|
      page.execute_script(<<~JS, theme, status)
        document.querySelector(`[data-theme=${arguments[0]}]`).insertAdjacentHTML("beforeend", `<div class="bg-base-100"><span id="probe-${arguments[0]}-${arguments[1]}" style="color: var(--color-${arguments[1]})">Aa</span></div>`)
      JS
      [ "#{theme} #{status}", text_contrast("#probe-#{theme}-#{status}") ]
    end
    expect(ratios.select { |_status, ratio| ratio < ContrastHelper::WCAG_AA }).to be_empty
  end

  # The theme's 0.85rem over a 40px field and a box, and each smaller size in proportion to its height, so a small button or badge keeps the regular one's shape rather than rounding into a pill.
  it "rounds a field, a box and their smaller sizes in proportion to their height" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    radii = %w[ .btn:not(.btn-sm) .btn-sm .alert .badge-sm ].map do |selector|
      find("[data-theme=organic] #{selector}", match: :first).evaluate_script("parseFloat(getComputedStyle(this).borderTopLeftRadius)")
    end
    expect(radii).to match [ 13.6, 10.88, 13.6, 6.67 ].map { a_value_within(0.01).of(it) }
  end

  # The dismiss slot stays on an alert with nothing to dismiss, so its icon, words and slot sit in the same columns as a dismissible alert's.
  it "lays out an alert in the same columns whether or not it can be dismissed" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    alerts = within(first("[data-theme=organic]", text: "Please fix the highlighted fields.")) { all(".alert-error") }
    columns = alerts.map { it.evaluate_script("getComputedStyle(this).gridTemplateColumns") }
    expect([ alerts.map { it.has_button?("Dismiss", wait: 0) }, columns.uniq.size ]).to eq [ [ true, false ], 1 ]
  end

  # The dismiss × matches the alert's leading icon at 24px, inside its 32px button.
  it "draws an alert's dismiss icon as large as its leading icon" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    alert = first("[data-theme=organic] .alert:has(button)", text: "Event was successfully updated.")
    expect(alert.evaluate_script("[ this.querySelector(':scope > svg'), this.querySelector('button svg') ].map(icon => icon.getBoundingClientRect().width)")).to eq [ 24, 24 ]
  end

  # WHY: the frame's first track holds the icon, so a track narrower than the icon lets it run toward the words.
  it "sets an alert's words 16px from its icon" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    alert = first("[data-theme=organic] .alert:has(button)", text: "Event was successfully updated.")
    expect(alert.evaluate_script("Math.round(this.querySelector(':scope > div').getBoundingClientRect().left - this.querySelector(':scope > svg').getBoundingClientRect().right)")).to eq 16
  end

  # The badge centres its line box, and Commissioner's descender room would leave a word with no descender sitting high, so the line is trimmed to the x-height. Measured on an "x" that inherits the trim: trimmed it is the x-height alone, about 6px, untrimmed the 18px line, centred either way.
  it "centres a badge's lowercase letters on their x-height" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    above, below, height = find("[data-theme=organic] .badge-sm", match: :first).evaluate_script(<<~JS)
      (probe => { probe.textContent = "x"; probe.style.cssText = "display: inline-block; text-box: inherit"; this.replaceChildren(probe); const box = this.getBoundingClientRect(), x = probe.getBoundingClientRect(); return [ x.top - box.top, box.bottom - x.bottom, x.height ] })(document.createElement("span"))
    JS
    expect([ (above - below).abs <= 0.5, height < 10 ]).to eq [ true, true ]
  end

  # Both mix the twin's own ink, so a token resolved once at the page's light root would read faint in the dark twin.
  it "dims icons to icon-muted and text to muted from each twin's own ink" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    ratios = %w[ organic organic-dark ].product(%w[ icon-muted muted ]).to_h do |theme, token|
      page.execute_script(<<~JS, theme, token)
        document.querySelector(`[data-theme=${arguments[0]}]`).insertAdjacentHTML("beforeend", `<div class="bg-base-100"><span id="probe-${arguments[0]}-${arguments[1]}" class="text-${arguments[1]}">Aa</span></div>`)
      JS
      [ "#{theme} #{token}", text_contrast("#probe-#{theme}-#{token}") ]
    end
    expect(ratios).to match("organic icon-muted" => be_between(3, 6), "organic muted" => be >= ContrastHelper::WCAG_AA, "organic-dark icon-muted" => be_between(3, 8), "organic-dark muted" => be >= ContrastHelper::WCAG_AA)
  end

  it "sets the type ladder's titles in Alegreya and its text in Commissioner" do
    plant_styleguide_group
    sign_in_as create(:user)

    visit styleguide_path

    ladder = find("section", text: "Type ladder")
    expect(ladder.all(".font-heading").map { it.evaluate_script("getComputedStyle(this).fontFamily") }).to match [ a_string_starting_with("Alegreya") ] * 8
    expect(ladder.all("p:not(.font-heading)").map { it.evaluate_script("getComputedStyle(this).fontFamily") }).to match [ a_string_starting_with("Commissioner") ] * 6
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

  context "with a section folded" do
    # The folds are kept in the browser's storage, which outlives the session Capybara resets, so they are cleared for the examples after.
    after { page.execute_script("localStorage.clear()") }

    it "keeps it folded through a reload and a member switch" do
      plant_styleguide_group(manager: "Ana Horvat")
      sign_in_as create(:user)
      ladder = "section[data-title='Type ladder'] [data-theme=organic]"

      visit styleguide_path
      find("section[data-title='Type ladder'] summary").click
      visit styleguide_path
      after_reload = page.has_no_css?(ladder, visible: :visible, wait: 1)
      select "Ana Horvat - owner, active", from: "Signed in as"

      expect(page).to have_css "a[aria-label='Edit group']"
      expect([ after_reload, page.has_no_css?(ladder, visible: :visible, wait: 1) ]).to eq [ true, true ]
    end

    # The two buttons in the switcher bar fold or unfold every section at once, and a reload keeps what they left, as it keeps a single fold.
    it "folds every section with Collapse all and unfolds them with Expand all" do
      plant_styleguide_group
      sign_in_as create(:user)
      open_count = "[...document.querySelectorAll('[data-controller~=fold] > details')].filter(details => details.open).length"

      visit styleguide_path
      click_button "Collapse all"
      visit styleguide_path
      collapsed = page.evaluate_script(open_count)
      click_button "Expand all"

      expect([ collapsed, page.evaluate_script(open_count) ]).to eq [ 0, page.all("[data-controller~=fold]", visible: :all).size ]
    end
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
