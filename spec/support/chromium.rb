module Chromium
  ENV_VAR = "CHROMIUM_PATH".freeze

  # Chromium only, deliberately. Ferrum's own Linux lookup is `chrome google-chrome
  # google-chrome-stable google-chrome-beta chromium chromium-browser google-chrome-unstable`, so
  # on a machine carrying both browsers it resolves Chrome and never reaches Chromium. The paint
  # matcher measures rendered pixels, so which engine drew them is part of what an assertion means.
  NAMES = %w[ chromium chromium-browser ].freeze

  class NotFound < StandardError
    def message
      <<~MESSAGE
        No Chromium binary found.

        The system specs drive Chromium over the DevTools Protocol, and nothing in the Gemfile
        provides one. Install it through your package manager, or point #{ENV_VAR} at the binary:

            #{ENV_VAR}=/path/to/chromium bin/ci

        Tried, on PATH: #{NAMES.join(", ")}
      MESSAGE
    end
  end

  class << self
    def path = ENV[ENV_VAR].presence || search || raise(NotFound)

    private
      def search = NAMES.lazy.filter_map { |name| which(name) }.first

      def which(name)
        ENV["PATH"].to_s.split(File::PATH_SEPARATOR).lazy.filter_map do |dir|
          candidate = File.join(dir, name)
          candidate if File.executable?(candidate) && !File.directory?(candidate)
        end.first
      end
  end
end
