class Feedback::FileIssueJob < ApplicationJob
  retry_on Feedback::GithubIssue::Error, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, OpenSSL::SSL::SSLError, wait: 10.minutes, attempts: 6

  def perform(feedback)
    feedback.file_issue
  end
end
