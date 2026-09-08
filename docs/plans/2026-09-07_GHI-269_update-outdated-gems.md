> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update outdated gems (#269)

## Approach

`bundle outdated` reports the same eight gems the issue names, and the lockfile settles which of them can move. Six can: `action_policy`, `bootsnap` and `image_processing` are direct dependencies whose requirements already admit the new versions, and `et-orbi`, `json` and `parallel` arrive transitively behind requirements the new versions satisfy - `fugit` wants `et-orbi (~> 1.4)`, `rubocop` wants `parallel (>= 1.10)` and `json (>= 2.3)`, and `activesupport` wants `json` unconstrained. Two cannot, for the reasons #204 already found and this lockfile still shows: `rspec-expectations` and `rspec-mocks` both pin `diff-lcs (>= 1.2.0, < 2.0)`, and `activestorage` pins `marcel (~> 1.0)`.

The toolchain moves before any gem does, so the bumps are resolved and locked by the Bundler this branch declares rather than by the one it replaces. `gem update --system` is what moves RubyGems and the Bundler it ships; it is a machine-wide install, so it is run by hand and never by an agent. Writing the result into `BUNDLED WITH` has a trap worth stating once: `bundle help config` documents the `version` key as defaulting to `lockfile`, so inside this repository Bundler re-execs the version the lockfile names, and a bare `bundle update --bundler` would write the old version straight back. The version has to be named, `bundle update --bundler=4.0.20`. Pinning `BUNDLE_VERSION=system` to sidestep that is the option #72 considered and rejected, because `ruby/setup-ruby` and the `Dockerfile` both read `BUNDLED WITH` and a lock disagreeing with the installed Bundler self-switches on every invocation.

`json` is the one major among the six and the only one nothing asks for directly, so it lands in its own commit, revertable without unpicking five uncontroversial minor bumps. Every update runs with `--conservative`, so nothing outside the named gems moves and the lockfile diff stays readable.

The rest of this branch exists because none of the above was discoverable when this round started. #72 had already decided the Bundler question and #204 had already found both pins, but each sat in a plan file, which is a frozen record of one branch rather than something a later round reads first, so both had to be rediscovered from the lockfile and the manuals. A new `.agents/dependencies.md` becomes the file that owns dependency work, holding the update order, the `BUNDLED WITH` trap, the two upstream pins, and everything about Dependabot. `.agents/gh-solo.md` is the wrong home for it: that file carries per-repo facts for the `gh-solo` skills, and a build procedure sitting there would misdescribe it.

Being written down is not the same as being read, so the new file gets two discovery paths. `CLAUDE.md` loads into every session automatically, and its entry names when to open the file rather than only that it exists, the way its `docs/AUTHORIZATION.md` entry already does and its `.agents/gh-solo.md` entry does not. The second path is a pointer left in `.agents/gh-solo.md`, which the `implement` skill's contract obliges an agent to read for this repository's check commands, so it is a stronger guarantee than a line in a file an agent may skim. Both are advisory, and the only mechanism that would compel the read is a `PreToolUse` hook on `Gemfile.lock`, which is harness configuration rather than repository documentation and is deliberately out of scope here.

Dependabot moves into that file rather than being described twice, and the move corrects a claim that has turned out to be false. `.github/dependabot.yml` sets `labels: []` on both entries, added 2026-08-20 in d1c1d3f, and that is the mechanism GitHub documents for suppressing every label. GitHub's backend ignores it: dependabot/dependabot-core#11783 is open as of 2026-06-22, a recurrence of #6858, and the traced cause is that the label decision happens in the closed-source job generator rather than in `dependabot-core`'s own labeler, which handles an empty list correctly. So the configuration is right, no configuration change fixes it, and #266 and #267 carry `dependencies` and `ruby` regardless. The standing call is written as a rule rather than as a list of the two labels visible today, because the set grows on its own: `github_actions` is already configured and arrives with the first Actions update, and an npm ecosystem would bring its own.

## Steps

- Read each of the six changelogs, `json` 2.21 to 3.0 closely enough to know what it breaks and where this application would notice
- Move the toolchain first: `gem update --system` by hand, since no agent installs software, then `bundle update --bundler=4.0.20` so `Gemfile.lock` declares it
- Bump the five minor releases in one commit: `bundle update --conservative action_policy bootsnap image_processing et-orbi parallel`
- Bump `json` alone in a second commit: `bundle update --conservative json`
- Check that nothing moved in `Gemfile.lock` beyond the six gems and the `BUNDLED WITH` line, and strip whatever else did
- Write `.agents/dependencies.md`: the update order above, the `BUNDLED WITH` trap and why the version must be named, the two upstream pins holding `diff-lcs` and `marcel` down so a later round reads them instead of re-investigating, and the Dependabot section below
- Give that file the Dependabot content relocated from `.agents/gh-solo.md`, under a heading that claims nothing untrue: what a Dependabot pull request is for and that it is never merged, that Dependabot closes its own once `main` carries the version, and the label rule stated as a rule - a `dependencies` label on every such pull request, one ecosystem or language label per configured package manager, the SemVer labels where they exist, and every one of them left alone
- Remove the *Dependabot carries no labels* section from `.agents/gh-solo.md` and leave a one-line pointer in its place
- Add a dated correction to `docs/adr/2026-08-20_github-repository-conventions_0001.md` recording that the `labels: []` mechanism it describes is not honoured upstream, without rewriting the decision the record made
- Index `.agents/dependencies.md` in `CLAUDE.md` under *PROJECT KNOWLEDGE*, with the entry naming when to read it

## Verification

- `bin/ci` passes
- `bundle outdated action_policy bootsnap image_processing et-orbi json parallel` exits 0, having been seen to exit 1 before the bumps
- `test "$(grep -A1 '^BUNDLED WITH' Gemfile.lock | tail -1 | tr -d ' ')" = "4.0.20"` exits 0, having been seen to exit 1 against the locked 4.0.18
- `grep -q 'Dependabot carries no labels' .agents/gh-solo.md` exits 1, having been seen to exit 0 while the section is still there
- `grep -q 'dependencies.md' .agents/gh-solo.md` and `grep -q 'dependencies.md' CLAUDE.md` both exit 0, each having been seen to exit 1 before either pointer exists
- `python3 <skill-dir>/scripts/docs-check.py --root . --ignore '~/*' docs/plans/2026-09-07_GHI-269_update-outdated-gems.md .agents/dependencies.md .agents/gh-solo.md CLAUDE.md docs/adr/2026-08-20_github-repository-conventions_0001.md` exits 0, having been seen to exit 1 while this plan still names a file it has not created; the ignore covers the one backticked span in `CLAUDE.md` that points outside this repository

No gate here sees what `json` 3.0 changed. `bin/ci` proves the specs that exist still pass, and a major release's behaviour differences surface where a spec reaches, so a serialization path this suite does not cover is invisible to every box above. Nor does any gate read whether the new file is any good: the greps prove a pointer exists and a heading is gone, which is presence rather than prose worth reading, and whether a later round actually opens the file is a property of an agent's judgement that no exit code observes. The lockfile is read by eye for everything except the `BUNDLED WITH` line, since bare `bundle outdated` exits 1 for as long as `diff-lcs` and `marcel` stay pinned. Dependabot's self-close happens on `main` after this merges, so it is checked by looking at #266 and #267 afterwards, and the label defect is upstream and closes when GitHub fixes it rather than when this branch lands.

## Open questions

None.

## Settled

- **The toolchain moves by `gem update --system`, then `bundle update --bundler=4.0.20`.** `bundle` has no `--system` flag, and the owner ran the install by hand on 2026-09-07, taking RubyGems from 4.0.16 and Bundler from 4.0.18 to 4.0.20.
- **`json` is bumped to 3.0.0 as the criterion says**, rather than deferred, and the changelog read is the step that would reopen the question.
- **The `diff-lcs` and `marcel` criteria were reworded on the issue** so each states what is actually owed, the pin confirmed and recorded, rather than a bump annotated as blocked that could only ever be ticked untruthfully.
- **The documentation lands in a new `.agents/dependencies.md`**, indexed from `CLAUDE.md` with its read trigger and pointed at from `.agents/gh-solo.md`, which is the file the `implement` skill contract already obliges an agent to read.
- **`.github/dependabot.yml` is not changed and the labels are not deleted**, because the suppression defect is upstream and server-side; the rule covering it is written to cover labels this repository has not seen yet, and the ADR that described the mechanism gets a correction beside it rather than a rewrite.
