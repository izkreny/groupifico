RailsIcons.configure do |config|
  config.default_library = "heroicons"
  config.default_variant = "solid"

  # Every icon is filled, drawn from the set made for its size (`IconsHelper::VARIANTS`), so the outline set, which exists at 24px alone, is not synced.
  config.libraries.heroicons.exclude_variants = [ :outline ]

  # No default size class. The gem's own `size-6` lives in Ruby, where Tailwind's source scanner cannot see it, so an icon relying on it renders at zero width unless some template happens to spell the same class. Dropping it makes every call site state its size in the markup, which is the one place the scanner reads.
  config.libraries.heroicons.solid.default.css = nil
  config.libraries.heroicons.mini.default.css = nil
  config.libraries.heroicons.micro.default.css = nil
end

# Sprite mode is deliberately off - `config.default_sprite_location` is left unset - because inline SVG is what lets `currentColor` and the theme's semantic classes colour an icon.

# The engine prepends `/rails_icons/sprite.svg` to the application's routes in every environment, so the `Rails.env.development?` guard on the mount in `config/routes.rb` cannot reach it and a route drawn in that file cannot shadow it. This prepend can, because it is registered while `config/initializers` load and the engine's own runs `after: :load_config_initializers`.
unless Rails.env.development?
  Rails.application.routes.prepend do
    get "/rails_icons/sprite.svg", to: proc { raise ActionController::RoutingError, "Not Found" }
  end
end
