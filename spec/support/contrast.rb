# The compositing and the WCAG arithmetic both contrast measurements in this suite need, in one
# home so a correction to either lands once. `PaintMatcher` asks what an element's own background
# paints against its surface; `ContrastHelper` asks what an element's text reaches once the opacity
# it inherits is folded in, which is the step axe skips.
#
# The compositing is done by filling a 1x1 canvas rather than by parsing a colour string, and that
# is the whole trick. `getComputedStyle` reports a translucent fill uncomposited, so a ratio read
# straight off it describes a colour nobody sees; and this application's palette resolves to
# `oklch(...)`, which any `rgb()`-shaped parser reads as three unrelated numbers. Handing the
# string to `fillStyle` makes the browser do the conversion and the alpha blend, and the pixel that
# comes back is the one a person is looking at.
module Contrast
  # A canvas, a filler that clears the previous colour first, and a pixel reader. The double
  # assignment in `fill` is what makes an invalid or transparent colour land as transparent rather
  # than as whatever was there before.
  CANVAS = <<~JAVASCRIPT.freeze
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 1;
    const context = canvas.getContext("2d", { willReadFrequently: true });

    const fill = (colour) => {
      context.fillStyle = "rgba(0, 0, 0, 0)";
      context.fillStyle = colour;
      context.fillRect(0, 0, 1, 1);
    };

    const pixel = () => context.getImageData(0, 0, 1, 1).data;
  JAVASCRIPT

  # `document.body` is transparent in this application, and filling a cleared canvas with a
  # transparent colour leaves alpha at zero rather than inheriting anything, which is what the walk
  # is for: the surface is the first ancestor that paints something opaque.
  SURFACE = <<~JAVASCRIPT.freeze
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
  JAVASCRIPT

  # WCAG 2.1's relative luminance, and the ratio built from two of them.
  LUMINANCE = <<~JAVASCRIPT.freeze
    const luminance = ([ red, green, blue ]) => {
      const channel = (value) => {
        const ratio = value / 255;
        return ratio <= 0.03928 ? ratio / 12.92 : Math.pow((ratio + 0.055) / 1.055, 2.4);
      };
      return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue);
    };

    const ratio = (one, other) => {
      const lighter = Math.max(luminance(one), luminance(other));
      const darker = Math.min(luminance(one), luminance(other));
      return (lighter + 0.05) / (darker + 0.05);
    };
  JAVASCRIPT
end

# What an element's text actually reaches, with every ancestor's `opacity` folded into its colour
# before the comparison. axe-core does not composite an ancestor's opacity into its colour-contrast
# rule - watched passing at `opacity-10`, which is unreadable - so a dimmed row needs measuring
# rather than asserting.
module ContrastHelper
  # The ratio WCAG 2.1 AA asks of normal text, which is what `spec/support/axe.rb` enforces
  # everywhere it can see.
  WCAG_AA = 4.5

  def text_contrast(selector)
    page.evaluate_script(<<~JAVASCRIPT)
      (function(selector) {
        const element = document.querySelector(selector);
        if (!element) return null;

        #{Contrast::CANVAS}
        #{Contrast::SURFACE}
        #{Contrast::LUMINANCE}

        let alpha = 1;
        for (let node = element; node; node = node.parentElement) {
          alpha *= parseFloat(getComputedStyle(node).opacity);
        }

        context.clearRect(0, 0, 1, 1);
        fill(surface);
        const beneath = Array.from(pixel());

        context.clearRect(0, 0, 1, 1);
        fill(getComputedStyle(element).color);
        const ink = Array.from(pixel());

        const blended = ink.slice(0, 3).map((value, index) => value * alpha + beneath[index] * (1 - alpha));

        return ratio(blended, beneath);
      })("#{selector}")
    JAVASCRIPT
  end
end

RSpec.configure do |config|
  config.include ContrastHelper, type: :system
end
