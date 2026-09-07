# Dependency conventions for this repository

How a dependency moves here, what holds some of them where they are, and what a Dependabot pull request is for. This file wins on any conflict about dependency work. The GitHub conventions around the pull request that carries it live in [`gh-solo.md`](gh-solo.md), and the local gate is `bin/ci`, which that file owns.

Read this before bumping a gem, editing `Gemfile` or `Gemfile.lock`, or acting on a Dependabot pull request.

## The update order

The toolchain moves before any gem does, so the bumps are resolved and locked by the Bundler the branch declares rather than by the one it replaces.

1. **RubyGems and the Bundler it ships, by hand.** `gem update --system` is a machine-wide install, so the owner runs it and no agent does. Nothing in the repository changes at this step.
2. **The lockfile's declaration of it**, `bundle update --bundler=<version>`. The version is named and never implied, for the reason in *The `BUNDLED WITH` trap* below.
3. **The gems, with `--conservative`**, so nothing outside the named gems moves and the lockfile diff stays readable: `bundle update --conservative <gem> <gem> ...`.
4. **Each major release in its own commit**, so it stays revertable without unpicking the minor bumps beside it. Read its changelog before bumping, and read it closely where the gem arrives transitively, since nothing in `Gemfile` asked for it and a clean `bundle outdated` is the only thing the bump buys.

Then check the `Gemfile.lock` diff by eye against the trunk's copy: nothing should have moved beyond the gems named and, where step 2 ran, the `BUNDLED WITH` line.

## The `BUNDLED WITH` trap

`bundle help config` documents the `version` key as defaulting to `lockfile`, so inside this repository Bundler re-execs whatever `BUNDLED WITH` declares. A newly installed Bundler is therefore invisible until the lockfile names it: `bundle --version` answers the locked version, and a bare `bundle update --bundler` writes that same locked version straight back rather than moving it. Name the version.

Pinning `BUNDLE_VERSION=system` to sidestep this is the option #72 considered and rejected. `ruby/setup-ruby` with `bundler-cache: true` and no `bundler:` input installs the version `BUNDLED WITH` names, and the `Dockerfile`'s `bundle install` reaches the same version through the same lockfile switch, so that line is the whole propagation and a lock disagreeing with the installed Bundler self-switches on every invocation.

## Gems held below their latest release

Both are held by upstream requirements rather than by anything in this repository's own `Gemfile`, so neither is a defect to fix here and neither needs re-investigating. Re-read the requirement from `Gemfile.lock` when it next comes up, and move on.

- **`diff-lcs`** stays below 2.0. `rspec-expectations` and `rspec-mocks` both require `diff-lcs (>= 1.2.0, < 2.0)`. It moves when rspec does.
- **`marcel`** stays below 2.0. Rails' `activestorage` requires `marcel (~> 1.0)`. It moves when Rails does.

## A Dependabot pull request is a notification, and is never merged

It says an update exists. The bump lands by hand, in a pull request that closes an update issue, so the change arrives with a plan, a commit message in this repository's own vocabulary and a review like any other.

**Dependabot closes its own pull request once `main` carries the version.** Observed on #201, whose timeline shows it commenting that the gem is up to date, closing the pull request and deleting its branch, seconds after #205 landed the same bump by hand. So a bump that lands needs no manual close, and only a bump that is declined or deferred has to be closed by hand.

## Dependabot's labels are an upstream artefact, and are left alone

`.github/dependabot.yml` sets `labels: []` on every update entry, which is the mechanism GitHub documents for suppressing every label it would otherwise apply. **GitHub's backend ignores it**, per the open [dependabot/dependabot-core#11783](https://github.com/dependabot/dependabot-core/issues/11783), a recurrence of [#6858](https://github.com/dependabot/dependabot-core/issues/6858). The decision is made in the closed-source job generator rather than in `dependabot-core`'s own labeler, which handles an empty list correctly, so no change to that config file fixes it and the empty list stays as the correct declaration of intent.

The labels this produces, as a rule rather than a list, because the set grows whenever an ecosystem is added:

- A `dependencies` label on every Dependabot pull request.
- One ecosystem or language label per package manager configured in `.github/dependabot.yml`.
- The SemVer labels `major`, `minor` and `patch`, wherever those already exist in the repository.

**Leave every one of them alone.** Deleting a label undoes itself on the next weekly run, which recreates it if it is missing, and none of them is part of this repository's own taxonomy: the layer axis in [`gh-solo.md`](gh-solo.md) is what this repository labels with, on issues rather than on pull requests. A label appearing on a Dependabot pull request is upstream's doing and carries no meaning here.
