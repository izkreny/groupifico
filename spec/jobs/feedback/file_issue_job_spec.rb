require "rails_helper"

RSpec.describe Feedback::FileIssueJob, type: :job do
  include ActiveJob::TestHelper

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

  it "tries again within seconds when GitHub is first unreachable" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_timeout
    freeze_time

    expect { described_class.perform_now(feedback) }
      .to have_enqueued_job(described_class).with(feedback).at(be_within(1.second).of(3.seconds.from_now))
  end

  it "gives up after eleven attempts, which spread over about seven hours of outage" do
    feedback = create(:feedback)
    search = stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_timeout

    # WHY: `perform_enqueued_jobs` runs its block under `assert_nothing_raised`, which wraps the error the last attempt lets through.
    expect { perform_enqueued_jobs { described_class.perform_later(feedback) } }.to raise_error(Minitest::UnexpectedError) { expect(it.error).to be_a Net::OpenTimeout }
    expect(search).to have_been_made.times(11)
  end

  it "tries again when the host has no route to GitHub" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_raise(Errno::EHOSTUNREACH)

    expect { described_class.perform_now(feedback) }.to have_enqueued_job(described_class).with(feedback)
  end

  it "tries again when the host's network is down" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_raise(Errno::ENETUNREACH)

    expect { described_class.perform_now(feedback) }.to have_enqueued_job(described_class).with(feedback)
  end

  it "tries again when sending a screenshot to GitHub times out" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_raise(Net::WriteTimeout)

    expect { described_class.perform_now(feedback) }.to have_enqueued_job(described_class).with(feedback)
  end

  it "tries again when GitHub refuses the request" do
    feedback = create(:feedback)
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/acme/feedback/issues\?}).to_return(status: 502)

    expect { described_class.perform_now(feedback) }.to have_enqueued_job(described_class).with(feedback)
  end
end
