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
      feedback = build(:feedback, screenshots: [ upload("screenshot-1.png", "text/plain") ])

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
      bytes = file_fixture("screenshot-1.png").binread + ("\0" * 5.megabytes)
      large = Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/png", original_filename: "large.png")
      feedback = build(:feedback, screenshots: [ large ])

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "large.png is larger than 5 MB, the most a screenshot can be." ]
    end

    it "refuses a fourth screenshot" do
      feedback = build(:feedback, screenshots: Array.new(4) { upload("screenshot-1.png", "image/png") })

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "You can add at most 3 screenshots." ]
    end

    it "refuses a screenshot named by a stored file's signed id, which would skip every check on its content" do
      blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("notes.txt").open, filename: "notes.svg", content_type: "image/svg+xml")
      feedback = build(:feedback, screenshots: [ blob.signed_id ])

      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to eq [ "A screenshot has to be picked from your device." ]
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

  describe ".prune" do
    it "removes filed feedback and its screenshots once 66 days have passed since it was saved" do
      freeze_time
      expired = create(:feedback, issue_number: 4, created_at: 66.days.ago - 1.second, screenshots: [ upload("screenshot-1.png", "image/png") ])
      kept = create(:feedback, issue_number: 5, created_at: 66.days.ago + 1.second)

      described_class.prune

      expect(described_class.pluck(:id)).to eq [ kept.id ]
      expect(ActiveStorage::Attachment.where(record: expired)).to be_empty
    end

    it "keeps feedback that never became an issue, however old, since it exists nowhere else" do
      unfiled = create(:feedback, created_at: 67.days.ago)

      described_class.prune

      expect(described_class.pluck(:id)).to eq [ unfiled.id ]
    end
  end

  describe "#page_group_id" do
    it "is the group a page inside a group belongs to" do
      expect(described_class.new(page: "/groups/7/events/3/edit").page_group_id).to eq "7"
    end

    it "is the group a group's own home page shows" do
      expect(described_class.new(page: "/groups/7").page_group_id).to eq "7"
    end

    it "is nothing for a page outside any group or one the app does not know" do
      expect([ described_class.new(page: "/user/profile/edit").page_group_id, described_class.new(page: "/nowhere").page_group_id ]).to eq [ nil, nil ]
    end
  end

  def upload(name, type)
    Rack::Test::UploadedFile.new(file_fixture(name), type)
  end
end
