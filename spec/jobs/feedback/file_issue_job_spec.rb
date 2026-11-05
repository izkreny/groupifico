require "rails_helper"

RSpec.describe Feedback::FileIssueJob, type: :job do
  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:github, :feedback_repository).and_return("acme/feedback")
    allow(Rails.application.credentials).to receive(:dig).with(:github, :feedback_token).and_return("test-token")
  end

  it "files the feedback's issue" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_return_json(body: [])
    stub_request(:post, "https://api.github.com/repos/acme/feedback/issues").to_return_json(status: 201, body: { number: 12 })

    described_class.perform_now(feedback)

    expect(feedback.reload.issue_number).to eq 12
  end

  it "tries again in 10 minutes when GitHub is unreachable" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_timeout
    freeze_time

    expect { described_class.perform_now(feedback) }
      .to have_enqueued_job(described_class).with(feedback).at(be_within(2.minutes).of(10.minutes.from_now))
  end

  it "tries again when GitHub refuses the request" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_return(status: 502)

    expect { described_class.perform_now(feedback) }.to have_enqueued_job(described_class).with(feedback)
  end
end
