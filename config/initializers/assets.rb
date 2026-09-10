# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# The Heroicons `rails_icons` syncs are read from disk and inlined into the page, never linked, so leaving them on the load path would digest 648 files into `public/assets` and the manifest for nothing to reference.
Rails.application.config.assets.excluded_paths << Rails.root.join("app/assets/svg")
