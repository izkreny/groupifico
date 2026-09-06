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

  # `app/assets/builds` is gitignored, so a fresh checkout has no compiled CSS and every page the
  # browser loads renders unstyled - which makes a paint assertion pass for the wrong reason. The
  # suite refuses outright without it; this is what stops that refusal being a daily surprise.
  step "Tests: Stylesheet", "bin/rails tailwindcss:build"
  # Last, and after the RSpec step: the browser suite is the slowest thing in this gate and should
  # not sit in front of everything else's result. `.rspec` excludes `spec/system` from every bare
  # run, the CI runner's included, so clearing the exclusion here is what admits it.
  step "Tests: System", "bin/rspec --exclude-pattern '' spec/system"
end
