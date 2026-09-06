require "rails_helper"

RSpec.describe Chromium do
  # Four branches, and the two that matter were found by review rather than by design: a value
  # naming nothing executable used to pass the check and die later inside Ferrum's launcher, and an
  # empty value used to count as an answer.
  describe ".path" do
    around do |example|
      original = ENV.fetch("CHROMIUM_PATH", nil)
      example.run
      ENV["CHROMIUM_PATH"] = original
    end

    it "takes the environment variable when it names an executable" do
      ENV["CHROMIUM_PATH"] = "/bin/sh"

      expect(described_class.path).to eq "/bin/sh"
    end

    it "refuses a value that names nothing executable, quoting it" do
      ENV["CHROMIUM_PATH"] = "/definitely/not/a/browser"

      expect { described_class.path }
        .to raise_error described_class::NotFound, /definitely\/not\/a\/browser/
    end

    it "refuses a value that names a directory" do
      ENV["CHROMIUM_PATH"] = "/tmp"

      expect { described_class.path }.to raise_error described_class::NotFound
    end

    it "searches when the variable is empty rather than treating it as an answer" do
      ENV["CHROMIUM_PATH"] = ""

      expect(described_class.path).to include("chromium")
    end

    it "names what it tried when the search finds nothing" do
      ENV["CHROMIUM_PATH"] = nil
      original_path = ENV.fetch("PATH", nil)
      ENV["PATH"] = "/nonexistent"

      expect { described_class.path }
        .to raise_error described_class::NotFound, /#{described_class::NAMES.join(", ")}/
    ensure
      ENV["PATH"] = original_path
    end
  end
end
