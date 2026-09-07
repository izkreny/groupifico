# Namespaced deliberately. `RSpec::Matchers.define` instance-evals its block, so a constant
# assigned inside it lands on Object and is reassigned on every match, which Ruby warns about.
module PaintMatcher
  # Composites the element's own background over the first ancestor that paints an opaque one and
  # reports the WCAG contrast ratio between the two.
  #
  # The compositing is done by filling a 1x1 canvas rather than by parsing the colour string, and
  # that is the whole trick. `getComputedStyle` reports a translucent fill uncomposited, so a ratio
  # read straight off it describes a colour nobody sees; and this application's palette resolves to
  # `oklch(...)`, which any `rgb()`-shaped parser reads as three unrelated numbers. Handing the
  # string to `fillStyle` makes the browser do the conversion and the alpha blend, and the pixel
  # that comes back is the one a person is looking at.
  #
  # `document.body` is transparent here, and filling a cleared canvas with a transparent colour
  # leaves alpha at zero rather than inheriting anything, which is what the ancestor walk is for.
  #
  # Wrapped in an immediately-invoked function because `evaluate_script` evaluates an expression: a
  # bare `const` or `return` at the top level is a syntax error in that position.
  SCRIPT = <<~JAVASCRIPT.freeze
    (function(selector) {
      const element = document.querySelector(selector);
      if (!element) return null;

      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = 1;
      const context = canvas.getContext("2d", { willReadFrequently: true });

      const fill = (colour) => {
        context.fillStyle = "rgba(0, 0, 0, 0)";
        context.fillStyle = colour;
        context.fillRect(0, 0, 1, 1);
      };

      const pixel = () => context.getImageData(0, 0, 1, 1).data;

      const opaque = (colour) => {
        context.clearRect(0, 0, 1, 1);
        fill(colour);
        return pixel()[3] === 255;
      };

      let surface = "rgb(255, 255, 255)";
      for (let node = element.parentElement; node; node = node.parentElement) {
        const colour = getComputedStyle(node).backgroundColor;
        if (opaque(colour)) { surface = colour; break; }
      }

      context.clearRect(0, 0, 1, 1);
      fill(surface);
      const beneath = Array.from(pixel());

      fill(getComputedStyle(element).backgroundColor);
      const composited = Array.from(pixel());

      const luminance = ([ red, green, blue ]) => {
        const channel = (value) => {
          const ratio = value / 255;
          return ratio <= 0.03928 ? ratio / 12.92 : Math.pow((ratio + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue);
      };

      const lighter = Math.max(luminance(composited), luminance(beneath));
      const darker = Math.min(luminance(composited), luminance(beneath));
      return (lighter + 0.05) / (darker + 0.05);
    })(arguments[0])
  JAVASCRIPT

  # Floating point, not a legibility threshold. An element painting nothing scores exactly 1.0, and
  # this margin only keeps arithmetic noise from reading as a difference.
  EPSILON = 0.01
end

RSpec::Matchers.define :paint do
  match do |page|
    @ratio = page.evaluate_script(PaintMatcher::SCRIPT, selector)
    !@ratio.nil? && @ratio > 1 + PaintMatcher::EPSILON
  end

  failure_message do
    next "expected #{selector} to exist on the page" if @ratio.nil?
    "expected #{selector} to paint against the surface behind it, " \
      "but its contrast ratio there is #{@ratio.round(2)}"
  end

  failure_message_when_negated do
    "expected #{selector} not to paint, but its contrast ratio against the surface behind it " \
      "is #{@ratio.round(2)}"
  end

  # `expected` already unwraps a single argument. Reaching for `.first` here returns the selector's
  # first character instead, because ActiveSupport defines `String#first`.
  def selector = expected
end
