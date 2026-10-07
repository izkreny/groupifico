# Dependency conventions for this repository

What an update round is, how each dependency in it moves, what holds some of them where they are, and what a Dependabot pull request is for. This file wins on any conflict about dependency work. The GitHub conventions around the pull request that carries it live in [`gh-solo.md`](gh-solo.md), and the local gate is `bin/ci`, which that file owns.

Read this before opening or working an update issue, bumping a gem or any other package, editing `Gemfile`, `Gemfile.lock`, `package.json` or `package-lock.json`, or acting on a Dependabot pull request.

## An update round

**One update issue covers every upgradable package in the repository**: Ruby and its toolchain, the gems, Node and the npm packages, the vendored daisyUI and the GitHub Actions. A round is never split per ecosystem. The inventory below is taken whole before the issue's scope is fixed, and whatever it finds either moves in that round or is named in the issue as deliberately left where it is, so no ecosystem waits for someone to notice it.

**Every Ruby and Node command in a round runs as `mise exec -- <command>`**, so the worktree's `.ruby-version` and `.node-version` decide which Ruby and Node answer, rather than whatever the shell started with. It matters most in a round that moves Ruby or Node, where the shell still carries the version the branch is replacing. The commands in this section and in *The update order* are written that way, and a Ruby or Node command this file names elsewhere, `bin/ci` included, runs the same way.

### The inventory

Each entry is what to compare and the commands that read both sides:

- **Ruby**: `.ruby-version` against `mise latest ruby@<major.minor>` for a patch and `mise latest ruby` for a new minor, which is a decision for the issue rather than a routine bump. The `Dockerfile`'s `ARG RUBY_VERSION` names the same version.
- **RubyGems**: `mise exec -- gem --version` against `mise exec -- gem list --remote --exact rubygems-update`.
- **Bundler**: the `BUNDLED WITH` line in `Gemfile.lock` against `mise exec -- gem list --remote --exact bundler`. Never `bundle --version`, which answers the locked version, per *The `BUNDLED WITH` trap* below.
- **Node**: `.node-version` against `mise latest node`, and where each major stands in its life against the release schedule, `gh api repos/nodejs/Release/contents/schedule.json -H 'Accept: application/vnd.github.raw' --jq '."v<major>"'`, read for the current major and the next one, since its LTS and maintenance dates decide whether a major is worth taking early.
- **The gems**: `mise exec -- bundle outdated`, transitive gems included, since a transitive bump is still a bump the round takes. The gems held below their latest release appear in it and stay where they are.
- **The npm packages**: `mise exec -- npm outdated` and `mise exec -- npm audit`, both after `mise exec -- npm ci`. An audit finding is in scope even where nothing is outdated, which `npm outdated` cannot see.
- **The GitHub Actions majors**: every `uses:` line, `grep -ho 'uses: [^ ]*' .github/workflows/*.yml | sort -u`, against `gh release view --repo <owner>/<action> --json tagName --jq .tagName` for each. Every `uses:` names a major tag, so only a new major is an edit.
- **The importmap pins**: `config/importmap.rb` pins Turbo and Stimulus to the files the `turbo-rails` and `stimulus-rails` gems serve, so they move when those gems appear in `bundle outdated` and never on their own. `grep -n '@[0-9]' config/importmap.rb` finding nothing confirms that no pin carries an npm version; a pin it does find moves with `mise exec -- bin/importmap outdated`, and that command alone cannot tell no npm pins from current ones.
- **The vendored daisyUI**: `grep -o 'var version = "[^"]*"' app/assets/tailwind/daisyui.mjs` against `gh release view --repo saadeghi/daisyui --json tagName --jq .tagName`. No package manager reports it as outdated, so this comparison is what finds it.

## The update order

The toolchain moves before any gem does, so the bumps are resolved and locked by the Ruby and the Bundler the branch declares rather than by the ones it replaces. The ecosystems outside Ruby follow the gems, each in its own commit.

1. **Ruby, when it moves**: the owner installs it, since that is a machine-wide install, and the branch names it in `.ruby-version` and the `Dockerfile`'s `ARG RUBY_VERSION` together, in its own commit.
2. **RubyGems and Bundler, by hand**: `mise exec -- gem update --system`, then `mise exec -- gem install bundler -v <version>`, which puts the gem in the cache the next step checksums. Both are machine-wide installs, so the owner runs them and no agent does. Nothing in the repository changes at this step.
3. **The lockfile's declaration of it**, `mise exec -- bundle update --bundler=<version>`. The version is named and never implied, for the reason in *The `BUNDLED WITH` trap* below. It also writes Bundler's own `bundler (<version>) sha256=…` line under `CHECKSUMS`.
4. **The gems, with `--conservative`**, so nothing outside the named gems moves and the lockfile diff stays readable: `mise exec -- bundle update --conservative <gem> <gem> ...`.
5. **Each major release in its own commit**, so it stays revertable without unpicking the minor bumps beside it. Read its changelog before bumping, and read it closely where the gem arrives transitively, since nothing in `Gemfile` asked for it and a clean `bundle outdated` is the only thing the bump buys.
6. **Node, when it moves**: the owner installs it, and the branch names the major in `.node-version`, which the CI `lint` job's `actions/setup-node` reads, then runs `mise exec -- npm ci` under it.
7. **The npm packages**: an outdated one moves by naming its version, `mise exec -- npm install --save-exact <package>@<version>`, which keeps the exact pin `package.json` carries. Then `mise exec -- npm audit fix`, **never with `--force`**: without it the fix stays inside the ranges `package.json` declares and moves `package-lock.json` alone, where `--force` may install a breaking major. An advisory only `--force` can fix is a decision for the issue.
8. **The vendored daisyUI**, through `bin/update-daisyui`, naming the old and new versions in the commit body, since the script fetches whatever release is newest and takes no version. This holds until #273 lands; #273 replaces this step with daisyUI moving as an npm package in the step above.
9. **The GitHub Actions majors**, by editing the tag on each `uses:` line, with the action's release notes read first for inputs the workflow passes.

Then check the `Gemfile.lock` diff by eye against the trunk's copy: nothing should have moved beyond the gems named and, where the lockfile's declaration moved, the `BUNDLED WITH` line and the `bundler (<version>)` checksum line.

## The changelog impact check

A package that ships markup or CSS, such as daisyUI or `rails_icons`, can change how the app renders without a line of the app's own code moving, and its source sits outside the diff in a gem or in `node_modules`. So **the round's plan carries the evidence for every such package that moves**, and the review judges that list against the diff:

- **The changelog entries** between the old and new versions that touch a class, component or attribute the app uses.
- **The views each one reaches**, found by searching for it, as in `grep -rln '<class or attribute>' app`.
- **The specs that cover those views**, by path, with any view no spec covers named as such.

A styling change of this kind, such as a component gaining an active look from an attribute the app already sets, shows nowhere else once the package's own files leave the diff.

## The `BUNDLED WITH` trap

`bundle help config` documents the `version` key as defaulting to `lockfile`, so inside this repository Bundler re-execs whatever `BUNDLED WITH` declares. A newly installed Bundler is therefore invisible until the lockfile names it: `bundle --version` answers the locked version, and a bare `bundle update --bundler` writes that same locked version straight back rather than moving it. Name the version.

Pinning `BUNDLE_VERSION=system` to sidestep this is the option #72 considered and rejected. `ruby/setup-ruby` with `bundler-cache: true` and no `bundler:` input installs the version `BUNDLED WITH` names, and the `Dockerfile`'s `bundle install` reaches the same version through the same lockfile switch, so that line is the whole propagation and a lock disagreeing with the installed Bundler self-switches on every invocation.

## Gems held below their latest release

None of these is a defect to fix here and none needs re-investigating. Re-read the requirement when it next comes up, and move on.

Held by upstream requirements rather than by anything in this repository, so `Gemfile.lock` is where to read them:

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
