class Feedback::FileIssueJob < ApplicationJob
  retry_on Feedback::GithubIssue::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError, wait: 10.minutes, attempts: 6

  def perform(feedback)
    feedback.file_issue
  end
end
