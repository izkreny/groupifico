> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: post before and after screenshots per criterion (#454)

## Approach

`.agents/gh-solo.md` gains a `## Screenshots per criterion` section, the per-repository home the `gh-solo` skills already read and let override their defaults. It states the convention as #451's screenshots comment shows it, per N1: one comment per pull request whose issue carries `frontend` or `fullstack`, a section per screen state headed by the criterion keys it shows, a Before/After table with a desktop row and a phone row, and the route path under every image. The criteria with nothing to picture, the closing "Also changed" section, the timing after the review round and the retake after a fix, and `gh`'s `--attach` flag each get their sentence, so every criterion of the issue maps to one part of the section.

**The sizes and the theme are the ones #451 used**, 1280×800 and 390×844 in the light theme, because a fixed pair is what makes one pull request's screenshots comparable with the next. "Before" is `main`'s code on the same data, which is what makes the two columns differ only by the branch. How the screenshots are taken stays out of the section: the issue asks for the convention, and this repository is public, so a method tied to this machine does not belong in it.

AC6 is an issue on the `gh-solo` plugin's own repository, `izkreny/agentifico`, labelled `gh-solo` and `someday` since it asks for the convention "one day". Its body names #454 as where the convention lives today and carries nothing about this machine.

## Steps

- ::S1:: Add `## Screenshots per criterion` to `.agents/gh-solo.md`, before `## Dependencies`, stating who gets the comment and its sections (AC1), the spec-example section and the "Also changed" section (AC2), the two widths, the theme and the route path (AC3), the timing and the retake (AC4), and the `--attach` flag (AC5)
- ::S2:: Open the upstream issue on `izkreny/agentifico` with the labels `gh-solo` and `someday`, naming #454, and record its number on this pull request (AC6)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-12_GHI-454_screenshots-per-criterion.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-12_GHI-454_screenshots-per-criterion.md .agents/gh-solo.md` exits 0
- ::V3:: `gh issue view <upstream-number> --repo izkreny/agentifico --json labels` exits 0 and lists `gh-solo` and `someday`
- ::V4:: `mise exec -- bin/ci` passes, browser suite included

No test can read whether the section says what the owner means; AC1 to AC5 are the owner's to judge from `.agents/gh-solo.md` in the diff, and AC6 from the upstream issue's body.

## Open questions

None.

## Settled

None yet.
