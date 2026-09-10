module ViewportHelper
  # The widths the shell's one breakpoint separates: the column caps at 640px and the tabs move
  # from the dock into the header there. The driver's own window is 1400 wide, which is the desktop
  # side, so a spec asserting either placement has to say which side it is on.
  MOBILE  = [ 390, 844 ].freeze
  DESKTOP = [ 1400, 1400 ].freeze

  # State the width in the example rather than leaning on the driver reset, so a pair of examples
  # passes under the random order `spec/spec_helper.rb` configures.
  def resize_to(viewport)
    page.driver.resize(*viewport)
  end

  # Whether text is cut off by `truncate` is geometry rather than markup: the element carries the
  # whole string either way, so only the browser can answer it.
  def truncated?(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{selector}");
        return el.scrollWidth > el.clientWidth + 1;
      })()
    JS
  end
end
