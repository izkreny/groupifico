require "rails_helper"

RSpec.describe Feedback, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:description).is_at_most(5_000) }
    it { is_expected.to validate_length_of(:user_agent).is_at_most(1_000) }
    it { is_expected.to validate_numericality_of(:viewport_width).only_integer.is_in(1..20_000).allow_nil }
    it { is_expected.to validate_numericality_of(:pixel_ratio).is_in(0.1..10).allow_nil }
    it { is_expected.to validate_inclusion_of(:color_scheme).in_array(%w[ light dark ]).allow_blank }
    it { is_expected.to validate_inclusion_of(:display_mode).in_array(%w[ standalone browser ]).allow_blank }

    it "refuses a time zone that is not a zone name" do
      feedback = build(:feedback, time_zone: "<script>")

      expect(feedback).not_to be_valid
    end

    it "accepts a PNG whatever type the browser declares for it" do
      feedback = build(:feedback, screenshots: [ upload("screenshot.png", "text/plain") ])

      expect(feedback).to be_valid
    end

    it "refuses a text file the browser declares as a PNG" do
      feedback = build(:feedback, screenshots: [ upload("notes.txt", "image/png") ])

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "notes.txt isn't a PNG, JPEG, GIF or WebP image." ]
    end

    it "refuses a HEIC photo with a hint to take a screenshot" do
      feedback = build(:feedback, screenshots: [ upload("photo.heic", "image/heic") ])

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "photo.heic is a HEIC photo, which can't be sent. Take a screenshot instead." ]
    end

    it "refuses a screenshot larger than 5 MB" do
      bytes = file_fixture("screenshot.png").binread + ("\0" * 5.megabytes)
      large = Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/png", original_filename: "large.png")
      feedback = build(:feedback, screenshots: [ large ])

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "large.png is larger than 5 MB, the most a screenshot can be." ]
    end

    it "refuses a fourth screenshot" do
      feedback = build(:feedback, screenshots: Array.new(4) { upload("screenshot.png", "image/png") })

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "You can add at most 3 screenshots." ]
    end
  end

  describe "#page=" do
    it "keeps the path only, so a token in the query string is never stored" do
      feedback = described_class.new(page: "https://groupifico.test/sign_in/abc?token=secret#top")

      expect(feedback.page).to eq "/sign_in/abc"
    end

    it "stores nothing for a path that would lead to another site" do
      feedback = described_class.new(page: "https://groupifico.test//evil.example/sign_in")

      expect(feedback.page).to be_nil
    end

    it "stores nothing for a page that is not a URL" do
      feedback = described_class.new(page: "http://exa mple.com")

      expect(feedback.page).to be_nil
    end
  end

  def upload(name, type)
    Rack::Test::UploadedFile.new(file_fixture(name), type)
  end
end
