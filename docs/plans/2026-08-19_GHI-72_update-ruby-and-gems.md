# Plan: update ruby to 4.0.6 and gems

Issue: #72

Written retroactively, after the work landed. Recorded so the branch carries the reasoning the issue does not, and so the divergence at the end is visible rather than lost.

## Context

The working tree was restored from a WSL backup with no Ruby installed at all, which made the version choice free: there was no existing install to preserve and nothing to migrate. That turned the question from "is upgrading worth the risk" into "is there any reason not to take the current release", which is a much easier question.

## Steps

- Decide between staying on 3.4.x and moving to 4.0.6, on evidence rather than preference: resolve the whole `Gemfile` in a throwaway directory under each version and compare, then grep the application for the Ruby 4.0 breaking-change patterns that actually bite (`Set` moved to core, `cgi` dropped from the default gems, splatting `nil`, `Kernel#open` with a leading pipe, the changed Ractor API, and the removal of `Process::Status#&` and `#>>`)
- Set `.ruby-version` to `4.0.6`, and sync the `Dockerfile`'s `ARG RUBY_VERSION` in the same change, since it had drifted to `3.4.7` independently of the version file
- Install and then update every gem, in that order, so a resolution failure is distinguishable from an update failure
- Bring the locked Bundler forward with `bundle update --bundler`, rather than pinning `BUNDLE_VERSION=system`, because `ruby/setup-ruby` in CI and the `Dockerfile` both read `BUNDLED WITH` and a lock that disagrees with the installed Bundler makes it self-switch on every invocation
- Run `bin/rspec` and fix whatever it surfaces
- Run `bin/ci` as the last gate

## Verification

Gates, each with an exit code, and each one the implementing agent's to run and tick:

- `bin/rspec`, the full spec suite
- `bin/ci`, which is brakeman, bundler-audit, importmap audit, rubocop and rspec in sequence
- `bundle lock --update` resolving with no conflict under 4.0.6

What those gates cannot see, and what therefore needs judgement rather than a command:

- **Coverage stops at models.** There are no request, system or integration specs, so a controller or view regression would pass every gate above. The boot failure this branch fixes was caught only because `bin/rspec` loads `config/environment.rb` on its way in, not because any spec exercised Active Storage. Treat a green suite here as evidence about models and about boot, and about nothing else.
- **`system-test` in CI runs no tests.** Its step is commented out in `.github/workflows/ci.yml`, so the job passes unconditionally.
- **Nothing exercises the Docker image.** The `ARG RUBY_VERSION` change is unverified until something builds the image, which no gate on this branch does.

## Outcome, where it diverged from the plan

The step list held, but it did not anticipate the one real defect, and that is worth recording rather than smoothing over.

Rails 8.1.3.1 added `active_storage/vips.rb`, a file absent from 8.1.3, which eagerly requires `image_processing/vips` at boot so it can call `Vips.block_untrusted(true)`. Because `image_processing` declares `autoload :Vips`, the gem being present is not enough: something has to touch the constant, and this new file is what does. `ruby-vips` was not installed, and Active Storage's own rescue matches only `/libvips/` and `/image_processing/` while the message raised reads "ImageProcessing::Vips requires the ruby-vips gem", so it re-raised and took the boot with it.

The six `FrozenError: can't modify frozen Array` failures alongside it were one bug wearing seven hats. A `require` that raises is never recorded in `$LOADED_FEATURES`, so each subsequent spec file re-ran `config/environment.rb`, and the second `initialize!` tried to append to an `autoload_paths` that was already frozen. Adding `ruby-vips` to the `Gemfile` removed all seven at once.

The lesson for the next version bump: a patch-level Rails release can add a boot-time `require`, so "the gems resolved" is not "the application boots", and the two need separate checks.
