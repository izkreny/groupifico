require "rails_helper"

RSpec.describe Chromium do
  # Four branches, and the two that matter were found by review rather than by design: a value
  # naming nothing executable used to pass the check and die later inside Ferrum's launcher, and an
  # empty value used to count as an answer.
  #
  # Every example builds the PATH it needs in its own body rather than reading the host's. These
  # run inside the bare `bin/rspec` gate, which `.rspec` deliberately keeps free of the browser, so
  # asserting the outcome of a real search would make an installed Chromium a precondition of a
  # suite that is supposed to need none.
  describe ".path" do
    around do |example|
      original = { "CHROMIUM_PATH" => ENV.fetch("CHROMIUM_PATH", nil), "PATH" => ENV.fetch("PATH", nil) }
      example.run
      original.each { |name, value| ENV[name] = value }
    end

    let(:elsewhere) { Dir.mktmpdir }

    after { FileUtils.remove_entry(elsewhere) }

    def executable_at(path)
      File.write(path, "#!/bin/sh\n")
      File.chmod(0o755, path)
      path
    end

    # The two paths differ deliberately. Point the variable at the same binary the search would
    # find and the example passes even with the variable ignored entirely, which is what it is
    # here to rule out.
    it "prefers the environment variable to anything on PATH" do
      searchable = executable_at(File.join(elsewhere, "chromium"))
      named = executable_at(File.join(elsewhere, "some-other-browser"))
      ENV["PATH"] = elsewhere
      ENV["CHROMIUM_PATH"] = named

      expect(described_class.path).to eq named
      expect(described_class.path).not_to eq searchable
    end

    it "refuses a value that names nothing executable, quoting it" do
      ENV["CHROMIUM_PATH"] = "/definitely/not/a/browser"

      expect { described_class.path }
        .to raise_error described_class::NotFound, /definitely\/not\/a\/browser/
    end

    it "refuses a value that names a directory" do
      ENV["CHROMIUM_PATH"] = elsewhere

      expect { described_class.path }.to raise_error described_class::NotFound
    end

    it "searches when the variable is empty rather than treating it as an answer" do
      planted = executable_at(File.join(elsewhere, "chromium"))
      ENV["PATH"] = elsewhere
      ENV["CHROMIUM_PATH"] = ""

      expect(described_class.path).to eq planted
    end

    # The expected text is written out rather than interpolated from `NAMES`, so that reordering
    # or replacing the list breaks this example. Built from the constant it would mirror whatever
    # the constant said and pass on a list naming Chrome, which is the one browser `NAMES` exists
    # to exclude.
    it "names what it tried when the search finds nothing" do
      ENV["PATH"] = elsewhere
      ENV["CHROMIUM_PATH"] = nil

      expect { described_class.path }
        .to raise_error described_class::NotFound, /Tried, on PATH: chromium, chromium-browser/
    end
  end
end
