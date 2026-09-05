require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Groupifico
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # No attachment in the application needs a variant yet, and the vips default
    # would make libvips a boot dependency of every environment. Set this back to
    # :vips and install libvips in CI on the day variants are actually used.
    config.active_storage.variant_processor = :disabled

    # Every member is in one time zone today, so times render where the members
    # are rather than where the server is. Storage is untouched: this sets only
    # Time.zone, which is what a time-zone-aware attribute is read in, what a
    # datetime field renders and what a submitted string is parsed in, while
    # ActiveRecord.default_timezone stays :utc. #135 and #89 are the multi-zone
    # answer for the day one zone stops being true.
    config.time_zone = "Europe/Zagreb"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
