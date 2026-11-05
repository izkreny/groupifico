class Feedback::FileIssueJob < ApplicationJob
  # WHY: waits of about n⁴ seconds over 11 attempts span roughly 7 hours, so a GitHub outage of a few hours still ends in an issue.
  retry_on Feedback::GithubIssue::Error, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, OpenSSL::SSL::SSLError, wait: :polynomially_longer, attempts: 11

  def perform(feedback)
    feedback.file_issue
  end
end
