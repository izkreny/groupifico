module StyleguidesHelper
  # Where the themes are defined, read rather than copied, so the styleguide's swatches cannot drift from the palette the app paints.
  THEMES_STYLESHEET = Rails.root.join("app/assets/tailwind/application.css")

  # The named theme's daisyUI colour tokens, name to hex, in the order the stylesheet lists them.
  def theme_colours(theme)
    THEMES_STYLESHEET.read[/name: "#{Regexp.escape(theme)}";(.*?)\}/m, 1].scan(/--color-([a-z0-9-]+): (#\h{6});/).to_h
  end

  # The WCAG 2 contrast ratio of two hex colours, from 1 to 21, whichever is lighter.
  def contrast_ratio(one, other)
    lighter, darker = [ one, other ].map { relative_luminance(it) }.sort.reverse

    (lighter + 0.05) / (darker + 0.05)
  end

  # The token a colour is read against: each colour against its content colour and back, each base against the base content, and the base content against the page.
  def contrast_pair(name)
    case name
    when "base-content" then "base-100"
    when /\Abase-/      then "base-content"
    when /-content\z/   then name.delete_suffix("-content")
    else                     "#{name}-content"
    end
  end

  private
    def relative_luminance(hex)
      red, green, blue = hex.delete_prefix("#").scan(/../).map { linear(it.to_i(16) / 255.0) }

      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end

    def linear(channel)
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
end
