# Plain Ruby, no ActiveSupport and no Rails: `bin/setup` loads this before the environment exists,
# and the spec suite loads the same file, so there is one name list and one message rather than a
# copy per caller that drifts.
module Chromium
  ENV_VAR = "CHROMIUM_PATH".freeze

  # Chromium only, deliberately. Ferrum's own Linux lookup is `chrome google-chrome
  # google-chrome-stable google-chrome-beta chromium chromium-browser google-chrome-unstable`, so
  # on a machine carrying both browsers it resolves Chrome and never reaches Chromium. A paint
  # assertion is a claim about rendered pixels, so which engine drew them is part of its meaning.
  NAMES = %w[ chromium chromium-browser ].freeze

  class NotFound < StandardError
    def initialize(named = nil)
      super(named ? unusable(named) : missing)
    end

    private
      def unusable(named)
        <<~MESSAGE
          #{ENV_VAR} is set to #{named.inspect}, which is not an executable file.
        MESSAGE
      end

      def missing
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
    # An empty value falls through to the search rather than counting as an answer, and a value
    # naming something that is not executable is refused by name instead of being handed to Ferrum,
    # which fails later and further away.
    def path
      named = ENV[ENV_VAR].to_s.strip

      unless named.empty?
        raise NotFound, named unless executable?(named)
        return named
      end

      search || raise(NotFound)
    end

    private
      def search = NAMES.lazy.filter_map { |name| which(name) }.first

      def which(name)
        ENV["PATH"].to_s.split(File::PATH_SEPARATOR).lazy.filter_map do |dir|
          candidate = File.join(dir, name)
          candidate if executable?(candidate)
        end.first
      end

      def executable?(path) = File.executable?(path) && !File.directory?(path)
  end
end
