RailsIcons.configure do |config|
  config.default_library = "heroicons"
  config.default_variant = "outline"

  # Outline is what every screen draws; solid is reserved for a status badge. The 20px and 16px variants sync ~600 files nothing renders.
  config.libraries.heroicons.exclude_variants = [ :mini, :micro ]

  # Heroicons outline ships at 1.5 and the icon legend overrides it to 2 everywhere, so it is set once here rather than at each call site. The back chevron is the one exception and passes 2.5, from `IconsHelper::STROKE_WIDTHS`.
  config.libraries.heroicons.outline.default.stroke_width = "2"

  # No default size class. The gem's own `size-6` lives in Ruby, where Tailwind's source scanner cannot see it, so an icon relying on it renders at zero width unless some template happens to spell the same class. Dropping it makes every call site state its size in the markup, which is the one place the scanner reads.
  config.libraries.heroicons.outline.default.css = nil
  config.libraries.heroicons.solid.default.css = nil
end

# Sprite mode is deliberately off - `config.default_sprite_location` is left unset - because inline SVG is what lets `currentColor` and the theme's semantic classes colour an icon.
