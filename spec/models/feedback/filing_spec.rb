require "rails_helper"

RSpec.describe Feedback::Filing, type: :model do
  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:github, :feedback_repository).and_return("acme/feedback")
    allow(Rails.application.credentials).to receive(:dig).with(:github, :feedback_token).and_return("test-token")
  end

  it "files the feedback once it is saved" do
    expect { create(:feedback) }.to have_enqueued_job(Feedback::FileIssueJob)
  end

  describe "#file_issue" do
    it "opens one issue titled with the feedback's marker and records its number" do
      feedback = create(:feedback, description: "The dock hides the Save button.", page: "/groups/1/events", viewport_width: "390", viewport_height: "844")
      stub_issue_search(returning: [])
      opening = stub_request(:post, "https://api.github.com/repos/acme/feedback/issues")
        .with(headers: { "Authorization" => "Bearer test-token" }) { |request| JSON.parse(request.body)["title"] == "[F#{feedback.id}]" }
        .to_return_json(status: 201, body: { number: 7 })

      feedback.file_issue

      expect(opening).to have_been_made.once
      expect(feedback.reload.issue_number).to eq 7
    end

    it "carries the description, the context and each screenshot in the issue's body" do
      feedback = create(:feedback, description: "The dock hides the Save button.", page: "/groups/1/events", viewport_width: "390", viewport_height: "844", screenshots: [ screenshot ])
      stub_issue_search(returning: [])
      stub_screenshot_upload(returning: "https://github.com/user-attachments/assets/abc")
      bodies = stub_issue_opening(number: 7)

      # WHY: found afresh, as the job finds it, because the record `create` returned already holds its screenshots loaded.
      Feedback.find(feedback.id).file_issue

      expect(bodies.sole).to include("The dock hides the Save button.", "![Screenshot 1](https://github.com/user-attachments/assets/abc)", "- Page: /groups/1/events", "- Viewport: 390 × 844")
    end

    it "makes no GitHub call for a feedback that already has its issue" do
      feedback = create(:feedback, issue_number: 3)

      feedback.file_issue

      expect(a_request(:any, /github\.com/)).not_to have_been_made
    end

    it "records the issue an earlier, timed-out attempt opened instead of opening a second" do
      feedback = create(:feedback)
      stub_issue_search(returning: [ { title: "[F#{feedback.id}] Dock covers Save", number: 9 } ])

      feedback.file_issue

      expect(feedback.reload.issue_number).to eq 9
      expect(a_request(:post, "https://api.github.com/repos/acme/feedback/issues")).not_to have_been_made
    end

    it "leaves the feedback unfiled when GitHub refuses the issue" do
      feedback = create(:feedback)
      stub_issue_search(returning: [])
      stub_request(:post, "https://api.github.com/repos/acme/feedback/issues").to_return(status: 503)

      expect { feedback.file_issue }.to raise_error(Feedback::GithubIssue::Error, /503/)
      expect(feedback.reload.issue_number).to be_nil
    end
  end

  def screenshot
    Rack::Test::UploadedFile.new(file_fixture("screenshot.png"), "image/png")
  end

  def stub_screenshot_upload(returning:)
    stub_request(:get, "https://api.github.com/repos/acme/feedback").to_return_json(body: { id: 42 })
    stub_request(:post, "https://uploads.github.com/user-attachments/assets")
      .with(query: { name: "screenshot.png", content_type: "image/png", repository_id: "42" }, body: file_fixture("screenshot.png").binread)
      .to_return_json(status: 201, body: { url: returning })
  end

  def stub_issue_opening(number:)
    bodies = []
    stub_request(:post, "https://api.github.com/repos/acme/feedback/issues").to_return do |request|
      bodies << JSON.parse(request.body)["body"]
      { status: 201, body: { number: }.to_json, headers: { "Content-Type" => "application/json" } }
    end
    bodies
  end

  def stub_issue_search(returning:)
    stub_request(:get, "https://api.github.com/repos/acme/feedback/issues")
      .with(query: hash_including(state: "all"))
      .to_return_json(body: returning)
  end
end
