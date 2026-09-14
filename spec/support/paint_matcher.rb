# Namespaced deliberately. `RSpec::Matchers.define` instance-evals its block, so a constant
# assigned inside it lands on Object and is reassigned on every match, which Ruby warns about.
module PaintMatcher
  # Composites the element's own background over the first ancestor that paints an opaque one and
  # reports the WCAG contrast ratio between the two. The compositing, the ancestor walk and the
  # luminance arithmetic are `spec/support/contrast.rb`'s, shared with the text measurement there;
  # what is this matcher's own is reading `backgroundColor` rather than `color`.
  #
  # Wrapped in an immediately-invoked function because `evaluate_script` evaluates an expression: a
  # bare `const` or `return` at the top level is a syntax error in that position.
  SCRIPT = <<~JAVASCRIPT.freeze
    (function(selector) {
      const element = document.querySelector(selector);
      if (!element) return null;

      #{Contrast::CANVAS}
      #{Contrast::SURFACE}
      #{Contrast::LUMINANCE}

      context.clearRect(0, 0, 1, 1);
      fill(surface);
      const beneath = Array.from(pixel());

      fill(getComputedStyle(element).backgroundColor);
      const composited = Array.from(pixel());

      return ratio(composited, beneath);
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
