require "capybara/cuprite"
require Rails.root.join("lib/chromium")

# Rails resolves its screenshot directory as `Capybara.save_path.presence || "tmp/screenshots"`,
# and Capybara ships the setting empty, so without this a failing spec writes somewhere the issue
# and the README do not name.
Capybara.save_path = Rails.root.join("tmp/capybara")

Capybara.register_driver :chromium do |app|
  Capybara::Cuprite::Driver.new(app, browser_path: Chromium.path, window_size: [ 1400, 1400 ],
    # Cuprite's default is 5 seconds, which is Capybara's default wait plus nothing. A cold
    # Chromium start on a loaded machine passes that on its own, and the failure reads as a broken
    # spec rather than a slow browser.
    process_timeout: 30)
end

module Stylesheet
  PATH = Rails.root.join("app/assets/builds/tailwind.css")

  # Without this the whole layer is worthless rather than merely incomplete. `app/assets/builds` is
  # gitignored, so a fresh checkout has no compiled CSS, every page renders unstyled, and the paint
  # matcher's negative control passes because nothing on the page paints at all - a check that
  # passes on everything, which cannot be told from one that passes on nothing. Found exactly that
  # way while writing the control.
  MISSING = <<~MESSAGE.freeze
    No compiled stylesheet at #{PATH.relative_path_from(Rails.root)}.

    System specs assert what a page paints, so an unstyled page makes them pass for the wrong
    reason. Build it first:

        bin/rails tailwindcss:build

    `bin/ci` does this for you; a bare `bin/rspec spec/system` does not.
  MESSAGE

  def self.compiled? = PATH.exist? && PATH.size.positive?
end

RSpec.configure do |config|
  config.before(type: :system) do
    raise Stylesheet::MISSING unless Stylesheet.compiled?

    driven_by :chromium
  end
end
