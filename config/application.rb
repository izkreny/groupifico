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
    #
    # WHY: once rather than reloaded, because `ActionMailer::Base` is never reloaded and keeps the
    # `MailpaceDelivery` it was given, so a reloaded class would leave it holding a stale one.
    config.autoload_lib_once(ignore: %w[assets tasks])

    # WHY: in this class body and nowhere later. `add_delivery_method` is what defines the
    # `mailpace_settings=` writer, and `action_mailer.set_configs` calls that writer from a load
    # hook of its own, with the settings an environment file gave it. Hooks run in the order they
    # were registered, and a file in config/initializers registers after that one, so production
    # would not boot.
    ActiveSupport.on_load(:action_mailer) { add_delivery_method :mailpace, MailpaceDelivery }

    # No attachment in the application needs a variant yet, and the vips default
    # would make libvips a boot dependency of every environment. Set this back to
    # :vips and install libvips in CI on the day variants are actually used.
    config.active_storage.variant_processor = :disabled

    # WHY: the engine's direct-upload and disk routes answer without sign-in, and the app serves no blob URL: screenshots leave only through the filing job.
    config.active_storage.draw_routes = false

    # Every member is in one time zone today, so times render where the members
    # are rather than where the server is. Storage is untouched: this sets only
    # Time.zone, which is what a time-zone-aware attribute is read in, what a
    # datetime field renders and what a submitted string is parsed in, while
    # ActiveRecord.default_timezone stays :utc. #135 and #89 are the multi-zone
    # answer for the day one zone stops being true.
    config.time_zone = "Europe/Zagreb"

    # WHY: Kamal sets `KAMAL_VERSION` in the app container to the deployed commit, so feedback can name the revision it was sent from; blank in development.
    config.x.revision = ENV["KAMAL_VERSION"]

    # WHY: development and production would share the private feedback repository and its `[F<id>]` markers while numbering feedback apart, so only production and test file issues; `production.rb` and `test.rb` turn it on.
    config.x.file_feedback = false

    # WHY: an unset `config.x` key answers an empty, truthy options hash rather than nil, so the element picker's switch is declared off here and `config/environments/development.rb` alone turns it on.
    config.x.picks_file = nil

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
