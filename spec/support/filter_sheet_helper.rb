# What a filtered list's browser specs read off its shared bar, tabs and sheet. A screen draws one filtered list, so each helper finds the funnel, the sheet and the tabs by the shape `shared/filter_bar` gives every list rather than by one list's name.
module FilterSheetHelper
  FUNNEL = "button[aria-label^='Filter ']".freeze
  SHEET  = "dialog[id$='_filter_dialog']".freeze

  def pick_in_sheet(*labels)
    find(FUNNEL).click
    labels.each { find(SHEET).find("input[aria-label='#{it}']").click }
  end

  # Whether the funnel paints the named ink, read against a probe carrying that class, which must itself differ from the ink around it so a class that compiled to nothing cannot pass, and still clears 3:1 as an icon.
  def funnel_ink(ink)
    painted = page.evaluate_script(%((() => { const button = document.querySelector("#{FUNNEL}"), probe = document.createElement("span"); probe.className = "#{ink}"; button.parentElement.append(probe); const ink = getComputedStyle(probe).color, painted = getComputedStyle(button).color == ink && ink != getComputedStyle(button.parentElement).color; probe.remove(); return painted })()))
    [ painted, text_contrast(FUNNEL) >= ContrastHelper::WCAG_NON_TEXT ]
  end

  # Clear all and "Show N", the sheet's last two labelled buttons, each as its rounded top and left.
  def sheet_buttons
    find(SHEET).evaluate_script(<<~JS).map { Data.define(:top, :left).new(*it) }
      [ ...this.querySelectorAll("button.btn:not([aria-label])") ].slice(-2).map(button => button.getBoundingClientRect()).map(rect => [ Math.round(rect.top), Math.round(rect.left) ])
    JS
  end

  # The accessible names Chromium computed for the links whose name opens with one of the tabs, read from its accessibility tree rather than the markup, which is the name a screen reader announces.
  def tab_names(tabs)
    nodes = page.driver.browser.page.command("Accessibility.getFullAXTree")["nodes"]
    nodes.filter_map { it.dig("name", "value") if it.dig("role", "value") == "link" }.select { |name| tabs.any? { name.start_with?("#{it} (") } }
  end
end

RSpec.configure do |config|
  config.include FilterSheetHelper, type: :system
end
