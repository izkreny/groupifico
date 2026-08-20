# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
  # `db:seed:replant` leaves the seeds in the test database, so the suite starts from a reset one - #75.
  # Reset before the suite, not after the seed step: delete it and this run goes red instead of the next one.
  step "Tests: Reset database", "bin/rails db:test:prepare"
  step "Tests: Rails", "bin/rspec"
  # step "Tests: Rails", "bin/rails test"
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
