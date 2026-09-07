> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: update outdated gems (#269)

## Approach

`bundle outdated` reports the same eight gems the issue names, and the lockfile settles which of them can move. Six can: `action_policy`, `bootsnap` and `image_processing` are direct dependencies whose requirements already admit the new versions, and `et-orbi`, `json` and `parallel` arrive transitively behind requirements the new versions satisfy - `fugit` wants `et-orbi (~> 1.4)`, `rubocop` wants `parallel (>= 1.10)` and `json (>= 2.3)`, and `activesupport` wants `json` unconstrained. Two cannot, for the reasons #204 already found and this lockfile still shows: `rspec-expectations` and `rspec-mocks` both pin `diff-lcs (>= 1.2.0, < 2.0)`, and `activestorage` pins `marcel (~> 1.0)`.

`json` is the one major among the six and the only one nothing asks for directly, so it lands in its own commit. That keeps it revertable without unpicking five uncontroversial minor bumps, and it is the bump whose changelog is worth more than a skim. Every update runs with `--conservative`, so nothing outside the named gems moves and the lockfile diff stays readable.

The convention the last two acceptance criteria record is already the practice, and writing it down is what lets a later session tell whether an open Dependabot pull request wants closing, merging or leaving alone. It goes into `.agents/gh-solo.md` as a sibling section of *Dependabot carries no labels* rather than inside it, since that heading is about labels and would misdescribe a passage about the pull request's fate. #266 and #267 are the two announcements standing open right now; neither gets merged, and both close themselves once `main` carries the versions.

## Steps

- Read each of the six changelogs, `json` 2.21 to 3.0 closely enough to know what it breaks and where this application would notice
- Bump the five minor releases in one commit: `bundle update --conservative action_policy bootsnap image_processing et-orbi parallel`
- Bump `json` alone in a second commit: `bundle update --conservative json`
- Check that neither update moved `BUNDLED WITH` or any gem outside the six, and strip the change if it did
- Add the sibling section to `.agents/gh-solo.md`: a Dependabot pull request is a notification that an update exists and is never merged, the bump lands by hand in a pull request that closes an update issue, and Dependabot closes its own pull request once `main` carries the version - so a bump that lands needs no manual close and only one declined or deferred has to be closed by hand
- Record on the issue that `diff-lcs` and `marcel` are still pinned where #204 found them, quoting the requirements from this lockfile

## Verification

- `bin/ci` passes
- `bundle outdated action_policy bootsnap image_processing et-orbi json parallel` exits 0, having been seen to exit 1 before the bumps
- `python3 <skill-dir>/scripts/docs-check.py --root . docs/plans/2026-09-07_GHI-269_update-outdated-gems.md .agents/gh-solo.md` exits 0, having been seen to exit 1 on a plan carrying a stale path

No gate here sees what `json` 3.0 changed. `bin/ci` only proves the specs that exist still pass, and a major release's behaviour differences surface where a spec reaches, so a serialization path this suite does not cover is invisible to every box above. The lockfile is read by eye rather than gated: bare `bundle outdated` exits 1 for as long as `diff-lcs` and `marcel` stay pinned, so what proves nothing outside the six moved is Step 4 reading the `Gemfile.lock` diff against `main`, and what proves the two pins still hold is reading them in the lockfile. Nothing sees Dependabot's self-close either: that happens on `main` after this merges, so it is checked by looking at #266 and #267 afterwards rather than by any command run here.

## Open questions

- The `diff-lcs` and `marcel` acceptance criteria are worded as bumps that are then annotated as blocked, and both `ready` and `merge` audit the issue's boxes, so as written neither box can be ticked truthfully. Either they get reworded to what is actually owed - confirm the pin still holds and record it - or the owner says that recording the block in this plan and on the issue closes them as they stand.
- Nothing in this application asks for `json` directly, so its major bump buys a clean `bundle outdated` and no feature. If the changelog turns out to break something, the cheaper answer is to defer it and say so on the issue rather than to work around it; this plan bumps it because the criterion says to.

## Settled

None yet.
