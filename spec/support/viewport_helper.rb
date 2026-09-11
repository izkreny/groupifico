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

  # The gap in px between where text actually ends and the next element begins. Measured off a
  # `Range` over the text rather than off its element's box, because a flex `gap` holds two boxes
  # the same distance apart however wide they are: a box stretched past its own text leaves the
  # reader a hole and the box measurement none. `truncated?` cannot see it either, since
  # `scrollWidth > clientWidth` is false whether a box hugs its text or stretches past it.
  def gap_after_text(text_selector, next_selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{text_selector}");
        const range = document.createRange();
        range.selectNodeContents(el);
        const text = range.getBoundingClientRect();
        const next = document.querySelector("#{next_selector}").getBoundingClientRect();
        return Math.round(next.left - text.right);
      })()
    JS
  end

  # The px between an element's right edge and the right inner edge of its container - 0 where the
  # element sits at the end of the row. Neither measurement above answers this: remove the slack
  # that pushes the element there and every gap in the row stays what it was while the whole group
  # packs left.
  def gap_to_row_end(selector, container_selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{selector}").getBoundingClientRect();
        const box = document.querySelector("#{container_selector}");
        const rect = box.getBoundingClientRect();
        const pad = parseFloat(getComputedStyle(box).paddingRight);
        return Math.round(rect.right - pad - el.right);
      })()
    JS
  end
end
