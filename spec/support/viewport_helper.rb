module ViewportHelper
  # The widths the shell's one breakpoint separates. #244 caps the column at 640px and moves the
  # tabs from the dock into the header there, so a spec asserting either placement has to say which
  # side of it the browser is on - the driver's own window is 1400 wide, which is the desktop side.
  MOBILE  = [ 390, 844 ].freeze
  DESKTOP = [ 1400, 1400 ].freeze

  # Sits beside `prefer_colour_scheme` and is used the same way: state the width in the example
  # rather than leaning on the driver reset, so the pair passes under the random order
  # `spec/spec_helper.rb` configures.
  def resize_to(viewport)
    page.driver.resize(*viewport)
  end
end
