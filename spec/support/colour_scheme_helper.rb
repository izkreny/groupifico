module ColourSchemeHelper
  # Emulates the device preference the two daisyUI themes are selected by, so a spec can assert
  # what a page paints under each. There is no Capybara or Cuprite API for this: `prefers-color-
  # scheme` is a media feature the browser resolves from OS settings, and the DevTools Protocol's
  # `Emulation.setEmulatedMedia` is the only way to say otherwise. `Ferrum::Page#command` is
  # public, so nothing here reopens a gem class.
  #
  # Send it before `visit`. Every example that cares states its own preference rather than leaning
  # on the driver reset between examples, which is what keeps the pair passing under the random
  # order `spec/spec_helper.rb` configures.
  def prefer_colour_scheme(scheme)
    page.driver.browser.page.command("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-color-scheme", value: scheme.to_s } ])
  end

  # What the browser resolved the preference into, read off the root element. `color-scheme` is the
  # property each daisyUI theme sets, so it is the theme's own signature rather than a colour that
  # happens to differ.
  #
  # This is what makes "renders in dark" falsifiable, and the margin is not theoretical. Watched
  # failing with the emulation above stubbed out: the page then follows the developer's own OS
  # setting, both paint assertions stay green under either theme, and only this reading moves. On a
  # machine preferring dark it is the *light* example that goes red, which is the half of the pair
  # a spec without this assertion would have been passing for no reason at all.
  def rendered_colour_scheme
    page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
  end
end
